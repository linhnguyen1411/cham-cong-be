#!/bin/bash
# setup-cron.sh
# Script để setup cron job cho tự động tạo đăng ký ca mặc định
# Sử dụng whenever gem để quản lý cron jobs

# Lấy đường dẫn tuyệt đối của project
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RAILS_ENV="${RAILS_ENV:-production}"

echo "🔄 Đang cập nhật crontab với whenever..."
echo ""

# Chuyển đến thư mục project
cd "$SCRIPT_DIR" || exit 1

# Cập nhật crontab từ config/schedule.rb
RAILS_ENV=$RAILS_ENV bundle exec whenever --update-crontab

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Đã cập nhật crontab thành công!"
    echo ""
    echo "📋 Cron jobs hiện tại:"
    crontab -l | grep -A 2 -B 2 "shift_registrations" || echo "   (Không tìm thấy)"
    echo ""
    echo "💡 Lưu ý:"
    echo "   - Cron job sẽ chạy vào 00:01 Thứ 2 hàng tuần (giờ server)"
    echo "   - Đảm bảo server đã set timezone là Asia/Ho_Chi_Minh (UTC+7)"
    echo "   - Log sẽ được ghi vào: $SCRIPT_DIR/log/cron.log"
    echo ""
    echo "📝 Để xem cron jobs được generate:"
    echo "   bundle exec whenever"
    echo ""
    echo "📝 Để xóa tất cả cron jobs từ whenever:"
    echo "   bundle exec whenever --clear-crontab"
    echo ""
else
    echo ""
    echo "❌ Lỗi khi cập nhật crontab!"
    echo "   Kiểm tra lại config/schedule.rb và đảm bảo whenever gem đã được cài đặt."
    exit 1
fi
