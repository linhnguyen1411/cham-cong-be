#!/bin/bash

# Script để backup database từ production và restore vào local
# Usage: ./backup_and_restore.sh

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
VPS_IP="112.213.87.124"
VPS_USER="root"
BACKUP_DIR="./backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILENAME="cham_cong_backup_${TIMESTAMP}.sql"
BACKUP_FILENAME_GZ="${BACKUP_FILENAME}.gz"

# Database config (Production - lấy từ VPS)
# Script sẽ tự động lấy từ VPS hoặc dùng default
PROD_DB_HOST="${DATABASE_HOST:-localhost}"
PROD_DB_USER="${DATABASE_USERNAME:-postgres}"
PROD_DB_NAME="workspace_production"
PROD_DB_PASSWORD="${DATABASE_PASSWORD}"

# Local database config
LOCAL_DB_NAME="workspace_development"
LOCAL_DB_USER="${DATABASE_USERNAME:-postgres}"
LOCAL_DB_PASSWORD="${DATABASE_PASSWORD:-postgres}"

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Nếu không có password, thử lấy từ VPS
if [ -z "$PROD_DB_PASSWORD" ]; then
    log_warning "DATABASE_PASSWORD not set, trying to get from VPS..."
    # Thử lấy từ .env trên VPS (nếu có)
    PROD_DB_PASSWORD=$(ssh ${VPS_USER}@${VPS_IP} "grep DATABASE_PASSWORD /root/cham-cong-be/.env 2>/dev/null | cut -d'=' -f2 | tr -d '\"'" || echo "postgres")
    if [ -z "$PROD_DB_PASSWORD" ] || [ "$PROD_DB_PASSWORD" = "" ]; then
        PROD_DB_PASSWORD="postgres"  # Default fallback
        log_warning "Using default password 'postgres'. Set DATABASE_PASSWORD if different."
    fi
fi

# Tạo thư mục backup nếu chưa có
mkdir -p "${BACKUP_DIR}"

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║    💾 Backup & Restore Database Script         ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""

# Step 1: Backup từ Production
log_info "Step 1: Creating backup from production..."

# Kiểm tra kết nối VPS
if ! ssh -q ${VPS_USER}@${VPS_IP} "echo 'Connected'" >/dev/null 2>&1; then
    log_error "Cannot connect to VPS at ${VPS_IP}"
    echo "Make sure you can SSH: ssh ${VPS_USER}@${VPS_IP}"
    exit 1
fi

log_success "VPS is reachable"

# Tạo backup trên VPS
log_info "Creating database backup on VPS..."
BACKUP_RESULT=$(ssh ${VPS_USER}@${VPS_IP} bash << EOF
cd /tmp
rm -f /tmp/cham_cong_backup_*.sql.gz
export PGPASSWORD='${PROD_DB_PASSWORD}'
pg_dump -h ${PROD_DB_HOST} -U ${PROD_DB_USER} -d ${PROD_DB_NAME} -F p --clean --if-exists > /tmp/${BACKUP_FILENAME} 2>&1
DUMP_EXIT_CODE=\$?
if [ \$DUMP_EXIT_CODE -eq 0 ] && [ -f /tmp/${BACKUP_FILENAME} ] && [ -s /tmp/${BACKUP_FILENAME} ]; then
    gzip -f /tmp/${BACKUP_FILENAME}
    if [ -f /tmp/${BACKUP_FILENAME_GZ} ]; then
        echo "BACKUP_SUCCESS"
        ls -lh /tmp/${BACKUP_FILENAME_GZ} | awk '{print \$5}'
    else
        echo "BACKUP_FAILED: Compression failed"
    fi
else
    echo "BACKUP_FAILED: pg_dump exit code: \$DUMP_EXIT_CODE"
    if [ -f /tmp/${BACKUP_FILENAME} ]; then
        echo "File exists but might be empty"
        head -3 /tmp/${BACKUP_FILENAME} 2>/dev/null || echo "Cannot read file"
    else
        echo "Backup file was not created"
    fi
fi
EOF
)

# Parse backup result
if echo "$BACKUP_RESULT" | grep -q "BACKUP_SUCCESS"; then
    BACKUP_SIZE=$(echo "$BACKUP_RESULT" | grep -v "BACKUP_SUCCESS" | head -1)
    log_success "Backup created on VPS (${BACKUP_SIZE})"
    
    # Download backup về local
    log_info "Step 2: Downloading backup to local..."
    if scp ${VPS_USER}@${VPS_IP}:/tmp/${BACKUP_FILENAME_GZ} "${BACKUP_DIR}/" 2>/dev/null; then
        if [ -f "${BACKUP_DIR}/${BACKUP_FILENAME_GZ}" ]; then
            LOCAL_SIZE=$(ls -lh "${BACKUP_DIR}/${BACKUP_FILENAME_GZ}" | awk '{print $5}')
            log_success "Backup downloaded: ${BACKUP_FILENAME_GZ} (${LOCAL_SIZE})"
        else
            log_error "Download completed but file not found locally"
            exit 1
        fi
    else
        log_error "Failed to download backup from VPS"
        exit 1
    fi
    
    # Clean up remote backup
    ssh ${VPS_USER}@${VPS_IP} "rm -f /tmp/${BACKUP_FILENAME_GZ}" 2>/dev/null
else
    log_error "Backup creation failed"
    echo "$BACKUP_RESULT" | grep -v "BACKUP_" | while read line; do
        log_info "  → $line"
    done
    exit 1
fi

# Step 3: Restore vào local database
log_info "Step 3: Restoring to local database..."

# Kiểm tra database local có tồn tại không
if psql -U ${LOCAL_DB_USER} -lqt | cut -d \| -f 1 | grep -qw ${LOCAL_DB_NAME}; then
    log_warning "Local database '${LOCAL_DB_NAME}' already exists."
    log_info "Dropping existing database to ensure clean restore..."
    export PGPASSWORD="${LOCAL_DB_PASSWORD}"
    log_info "Terminating active connections to '${LOCAL_DB_NAME}'..."
    # Terminate all connections except current
    psql -U ${LOCAL_DB_USER} -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='${LOCAL_DB_NAME}' AND pid <> pg_backend_pid();" >/dev/null 2>&1 || true
    sleep 1

    # Use --force if supported (Postgres 13+)
    if dropdb --help 2>&1 | grep -q -- "--force"; then
        dropdb -U ${LOCAL_DB_USER} --force ${LOCAL_DB_NAME} || {
            log_error "Failed to drop existing database (force)"
            exit 1
        }
    else
        dropdb -U ${LOCAL_DB_USER} ${LOCAL_DB_NAME} || {
            log_error "Failed to drop existing database"
            exit 1
        }
    fi
    log_success "Existing database dropped"
fi

log_info "Creating fresh local database..."
export PGPASSWORD="${LOCAL_DB_PASSWORD}"
createdb -U ${LOCAL_DB_USER} ${LOCAL_DB_NAME} || {
    log_error "Failed to create local database"
    exit 1
}
log_success "Local database created"

# Unzip backup file
log_info "Extracting backup file..."
cd "${BACKUP_DIR}"
gunzip -f "${BACKUP_FILENAME_GZ}" || {
    log_error "Failed to extract backup file"
    exit 1
}

# Restore database
log_info "Restoring database (this may take a while)..."
export PGPASSWORD="${LOCAL_DB_PASSWORD}"
psql -U ${LOCAL_DB_USER} -d ${LOCAL_DB_NAME} < "${BACKUP_FILENAME}" 2>&1 | tee restore.log || {
    log_error "Failed to restore database"
    log_info "Check restore.log for details"
    exit 1
}

log_success "Database restored successfully!"

# Clean up extracted file (keep gzip)
rm -f "${BACKUP_FILENAME}"

# Run migrations (nếu có) - skip vì đã restore từ production
log_info "Step 4: Skipping migrations (database already restored from production)"
log_info "If you need to run migrations, run: RAILS_ENV=development bundle exec rails db:migrate"

log_success "✅ Backup and restore completed!"
echo ""
log_info "Backup file saved at: ${BACKUP_DIR}/${BACKUP_FILENAME_GZ}"
log_info "Local database: ${LOCAL_DB_NAME}"
echo ""

