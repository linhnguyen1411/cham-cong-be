# Cron Jobs - Tự động hóa hệ thống

## Mô tả

Hệ thống có 2 cron jobs tự động:

1. **Tự động tạo đăng ký ca mặc định**: Chạy vào **00:01 Thứ 2 hàng tuần**
2. **Xử lý quên checkout**: Chạy vào **02:00 mỗi sáng**

---

## 1. Tự động tạo đăng ký ca mặc định

### Mô tả

Hệ thống sẽ tự động tạo đăng ký ca mặc định cho tất cả nhân viên vào **00:01 Thứ 2 hàng tuần** (giờ Việt Nam).

## Logic

1. **Khi nào chạy**: 00:01 Thứ 2 hàng tuần (giờ Việt Nam)
2. **Đối tượng**: Tất cả nhân viên active (role = staff, status = active)
3. **Điều kiện**: Chỉ tạo nếu nhân viên chưa có đăng ký nào cho tuần đó (approved hoặc pending)
4. **Quy tắc đăng ký**:
   - `both_shifts`: Tự động đăng ký cả ca sáng và ca chiều cho tất cả 7 ngày
   - `morning_only`: Tự động đăng ký chỉ ca sáng cho tất cả 7 ngày
   - `afternoon_only`: Tự động đăng ký chỉ ca chiều cho tất cả 7 ngày
5. **Status**: Tất cả đăng ký tự động được tạo với status `approved` (tự động duyệt)

## Cài đặt

Hệ thống sử dụng gem `whenever` để quản lý cron jobs một cách dễ dàng.

### Bước 1: Cài đặt gem (nếu chưa có)

```bash
cd cham-cong-be
bundle install
```

### Bước 2: Setup cron job

**Cách 1: Sử dụng script setup-cron.sh (Khuyến nghị)**

```bash
cd cham-cong-be
./setup-cron.sh
```

Script này sẽ:
- Tự động cập nhật crontab từ `config/schedule.rb` bằng `whenever`
- Hiển thị thông tin cron job sau khi setup

**Cách 2: Sử dụng whenever trực tiếp**

```bash
cd cham-cong-be
RAILS_ENV=production bundle exec whenever --update-crontab
```

**Cách 3: Xem cron jobs sẽ được tạo (không cập nhật)**

```bash
cd cham-cong-be
bundle exec whenever
```

### Cấu hình

Cron job được định nghĩa trong `config/schedule.rb`:

```ruby
# Chạy vào 00:01 Thứ 2 hàng tuần
every 1.week, at: '0:01 am', roles: [:app] do
  rake "shift_registrations:auto_create_default"
end
```

**Lưu ý về timezone:**
- Đảm bảo server đã set timezone là `Asia/Ho_Chi_Minh` (UTC+7)
- Nếu server dùng UTC, cần điều chỉnh giờ trong `config/schedule.rb`

### Kiểm tra timezone server

```bash
# Kiểm tra timezone hiện tại
timedatectl

# Hoặc
date

# Set timezone Việt Nam (nếu cần)
sudo timedatectl set-timezone Asia/Ho_Chi_Minh
```

## Chạy thủ công (Test)

Để test task trước khi setup cron:

```bash
cd cham-cong-be
RAILS_ENV=production bundle exec rake shift_registrations:auto_create_default
```

## Log

Log sẽ được ghi vào: `cham-cong-be/log/cron.log`

## Xem log

```bash
tail -f cham-cong-be/log/cron.log
```

## Kiểm tra cron job

```bash
# Xem tất cả cron jobs
crontab -l

# Xem cron jobs được generate từ whenever (không cập nhật crontab)
bundle exec whenever

# Xem log cron (nếu có)
grep CRON /var/log/syslog
```

## Troubleshooting

### Cron job không chạy

1. **Kiểm tra cron service:**
   ```bash
   sudo systemctl status cron
   # Hoặc
   sudo service cron status
   ```

2. **Kiểm tra quyền thực thi:**
   ```bash
   chmod +x setup-cron.sh
   ```

3. **Kiểm tra đường dẫn:**
   - Đảm bảo đường dẫn trong cron job là đường dẫn tuyệt đối
   - Đảm bảo `bundle exec` có thể chạy được

4. **Kiểm tra log:**
   ```bash
   tail -f log/cron.log
   ```

### Timezone không đúng

Nếu cron job chạy sai giờ, kiểm tra và set timezone:

```bash
# Xem timezone hiện tại
timedatectl

# Set timezone VN
sudo timedatectl set-timezone Asia/Ho_Chi_Minh

# Restart cron service
sudo systemctl restart cron
```

## Tắt tự động tạo đăng ký

Nếu muốn tắt tính năng này:

```bash
# Xóa tất cả cron jobs từ whenever
bundle exec whenever --clear-crontab

# Hoặc xóa thủ công
crontab -l | grep -v "shift_registrations:auto_create_default" | crontab -
```

