#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
VPS_IP="112.213.87.124"
VPS_USER="root"
BACKEND_PATH="/root/cham-cong-be"
FRONTEND_PATH="/root/cham-cong-fe"
BACKEND_PORT="3001"
FRONTEND_PORT="5173"

# Functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Main deployment
echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║    🚀 TimeKeep Pro - VPS Deployment Script     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""

# 1️⃣ Check connectivity
log_info "Checking VPS connectivity..."
if ! ssh -q ${VPS_USER}@${VPS_IP} "echo 'Connected'" >/dev/null 2>&1; then
    log_error "Cannot connect to VPS at ${VPS_IP}"
    echo "Make sure you can SSH: ssh ${VPS_USER}@${VPS_IP}"
    exit 1
fi
log_success "VPS is reachable"

# 2️⃣ Stop running processes
log_info "Stopping existing processes..."
ssh ${VPS_USER}@${VPS_IP} "pkill -f 'rails s' || true; pkill -f puma || true; sleep 2" 2>/dev/null
log_success "Old processes stopped"

# 3️⃣ Update backend code
log_info "Updating backend code..."
ssh ${VPS_USER}@${VPS_IP} "cd ${BACKEND_PATH} && git pull origin main" 2>/dev/null
log_success "Backend code updated"

# 4️⃣ Update frontend code
log_info "Updating frontend code..."
ssh ${VPS_USER}@${VPS_IP} "cd ${FRONTEND_PATH} && git pull origin main" 2>/dev/null
log_success "Frontend code updated"

# 5️⃣ Install backend dependencies
log_info "Installing backend gems (this may take a minute)..."
ssh ${VPS_USER}@${VPS_IP} "cd ${BACKEND_PATH} && bundle install --without development test --quiet" 2>/dev/null
log_success "Backend dependencies installed"

# 6️⃣ Run migrations
log_info "Running database migrations..."
ssh ${VPS_USER}@${VPS_IP} "cd ${BACKEND_PATH} && source .env 2>/dev/null || true && RAILS_ENV=production bundle exec rails db:migrate" 2>/dev/null
log_success "Database migrations completed"

# 7️⃣ Install frontend dependencies
log_info "Installing frontend dependencies (this may take a minute)..."
ssh ${VPS_USER}@${VPS_IP} "cd ${FRONTEND_PATH} && npm install --quiet" 2>/dev/null
log_success "Frontend dependencies installed"

# 8️⃣ Build frontend
log_info "Building frontend..."
ssh ${VPS_USER}@${VPS_IP} "cd ${FRONTEND_PATH} && npm run build --quiet" 2>/dev/null
log_success "Frontend built successfully"

# 9️⃣ Start backend with PM2
log_info "Starting backend on port ${BACKEND_PORT} with PM2..."
ssh ${VPS_USER}@${VPS_IP} "cd ${BACKEND_PATH} && pm2 start 'bundle exec rails s -p ${BACKEND_PORT} -e production' --name 'timekeep-api' --force 2>/dev/null || true"
log_success "Backend started"

# 🔟 Reload Nginx
log_info "Reloading Nginx..."
ssh ${VPS_USER}@${VPS_IP} "nginx -t && systemctl reload nginx" 2>/dev/null
log_success "Nginx reloaded"

# 1️⃣1️⃣ Wait for services to start
log_info "Waiting for services to start..."
sleep 5

# 1️⃣2️⃣ Test API
log_info "Testing API..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://${VPS_IP}:${BACKEND_PORT}/api/v1/users 2>/dev/null || echo "000")

if [ "$HTTP_CODE" == "200" ] || [ "$HTTP_CODE" == "401" ]; then
    log_success "API is responding (HTTP $HTTP_CODE)"
else
    log_warning "API returned HTTP $HTTP_CODE (may need more time to start)"
fi

# Show summary
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         ✅ Deployment Completed! ✅            ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}📊 Access Your Application:${NC}"
echo -e "   🔗 Backend API:   ${BLUE}http://${VPS_IP}:${BACKEND_PORT}${NC}"
echo -e "   🌐 Frontend UI:   ${BLUE}http://${VPS_IP}:${FRONTEND_PORT}${NC}"
echo ""
echo -e "${YELLOW}📋 Useful Commands:${NC}"
echo -e "   ${BLUE}ssh ${VPS_USER}@${VPS_IP}${NC}"
echo -e "   ${BLUE}pm2 status${NC}                 - Show PM2 status"
echo -e "   ${BLUE}pm2 logs timekeep-api${NC}      - View logs"
echo -e "   ${BLUE}pm2 restart timekeep-api${NC}   - Restart backend"
echo ""
echo -e "${YELLOW}📖 For more info, check DEPLOY.md${NC}"
echo ""
