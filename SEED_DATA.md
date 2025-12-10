# Seed Data for TimeKeep Pro

Hướng dẫn seed data cho cơ sở dữ liệu Rails backend.

## Setup Database

Chạy các lệnh sau từ thư mục Rails backend:

```bash
rails db:create
rails db:migrate
rails db:seed
```

## Seed Data Contents

### Users (Admin & Staff)

1. **Admin User**
   - username: `admin`
   - password: `123456`
   - fullName: `Admin User`
   - role: `admin`

2. **Staff Users** (5 nhân viên)
   - **Nguyen Van A** - username: `nguyenvana` - sẽ có dữ liệu đi muộn
   - **Tran Thi B** - username: `tranthib` - sẽ có dữ liệu về sớm
   - **Pham Van C** - username: `phamvanc` - sẽ có dữ liệu đúng giờ tốt
   - **Hoang Thi D** - username: `hoangtid` - sẽ có dữ liệu mixed
   - **Dang Van E** - username: `dangvane` - sẽ có dữ liệu mixed

### Work Shifts (Ca làm việc)

1. **Ca sáng** (Morning Shift)
   - name: "Ca sáng"
   - startTime: "08:00"
   - endTime: "17:00"
   - lateThreshold: 30 (phút)

2. **Ca chiều** (Afternoon Shift) - Optional
   - name: "Ca chiều"
   - startTime: "14:00"
   - endTime: "23:00"
   - lateThreshold: 30

### Work Sessions - Test Cases

#### Case 1: Đi đúng giờ (On-Time)
- **Pham Van C** - Tất cả session từ ngày 1-7 tháng 12
  - Check-in: 08:15 (trong 30 phút quy định)
  - Check-out: 17:00 (đủ 8-9 giờ)
  - Expected: isOnTime = true, minutesLate = 0

#### Case 2: Đi muộn (Late Arrival)
- **Nguyen Van A** - Ngày 3, 5, 7 tháng 12
  - Check-in: 08:45, 09:00, 08:35 (vượt 30 phút)
  - minutesLate: 15, 30, 5
  - Expected: isOnTime = false, minutesLate = actual minutes

#### Case 3: Về sớm (Early Checkout)
- **Tran Thi B** - Ngày 2, 4, 6 tháng 12
  - Check-in: 08:10
  - Check-out: 16:30, 16:45, 16:00 (trước 17:00)
  - Expected: isEarlyCheckout = true, minutesBeforeEnd = 30, 15, 60

#### Case 4: Mixed (Vừa muộn vừa sớm)
- **Hoang Thi D** - Ngày 1-7 tháng 12
  - Ngày 1: Check-in 08:20, Check-out 17:00 (On-time)
  - Ngày 2: Check-in 09:00, Check-out 17:30 (Late but finish late)
  - Ngày 3: Check-in 08:05, Check-out 16:30 (On-time but early checkout)
  - Ngày 4: Check-in 09:10, Check-out 16:45 (Late and early checkout)

#### Case 5: Các ngày khác
- **Dang Van E** - Mix dữ liệu từ tháng 11, tháng 12
  - Tháng 11: 10-20 sessions (for "30 ngày" filter test)
  - Tháng 12: 5-7 sessions

### Duration Calculation

- Duration = (check-out time - check-in time) / 3600 seconds
- Expected ranges:
  - Normal: 8-9 hours
  - With early checkout: < 8 hours
  - With overtime: > 9 hours

### Metrics to Verify

#### Per User (7 ngày):
- totalSessions: tổng số ca làm
- onTimeCount: số lần đi đúng giờ
- lateCount: số lần đi muộn
- totalMinutesLate: tổng phút muộn
- earlyCheckoutCount: số lần về sớm
- totalMinutesEarlyCheckout: tổng phút về sớm
- totalHours: tổng giờ làm
- avgHours: giờ trung bình/ngày
- onTimeRate: % đi đúng giờ

#### Admin Dashboard:
- "Tất cả" filter: hiện tất cả 5 nhân viên
- "Đi muộn": Nguyen Van A, Hoang Thi D, Dang Van E
- "Về sớm": Tran Thi B, Hoang Thi D
- "Tốt" (≥80% on-time): Pham Van C, có thể Dang Van E

#### Date Filters Test:
- "Hôm nay": Không có dữ liệu (chạy seed vào ngày quá khứ)
- "7 ngày": Dữ liệu từ 2-9 tháng 12
- "30 ngày": Dữ liệu từ 9 tháng 11 - 9 tháng 12
- "Tất cả": Tất cả dữ liệu

### Top On-Time Employees:
1. Pham Van C - 100%
2. Dang Van E - ~85%
3. Hoang Thi D - ~50%
4. Nguyen Van A - ~30%
5. Tran Thi B - ~40%

## Rails Seed Script

File: `/db/seeds.rb` (hoặc `db_seeds.rb` trong project này)

Seed script đã tạo tất cả các test cases:
- Tạo 1 admin user + 5 staff users
- Tạo 1 ca sáng (08:00-17:00, threshold 30 phút)
- Tạo 35+ work sessions với 5 test scenarios khác nhau:
  1. **Pham Van C**: 7 sessions - Toàn bộ đi đúng giờ (100% on-time)
  2. **Nguyen Van A**: 7 sessions - 3 lần đi muộn (57% on-time)
  3. **Tran Thi B**: 7 sessions - 3 lần về sớm (57% on-time)
  4. **Hoang Thi D**: 7 sessions - Mixed muộn + sớm (57% on-time)
  5. **Dang Van E**: 7 + 22 sessions - 30-day history (57% + historical)

### Cách chạy

```bash
# Trong Rails backend directory:
rails db:seed

# Hoặc load file trực tiếp:
rails db:seed:replant  # Xóa + tạo lại toàn bộ
```

### Test Accounts

```
Admin:     username='admin',        password='123456'
Staff:     username='nguyenvana'    password='123456'
           username='tranthib'      password='123456'
           username='phamvanc'      password='123456'
           username='hoangtid'      password='123456'
           username='dangvane'      password='123456'
```

## Testing Checklist

### ✅ Filter "Tất cả" (All Staff)
- [ ] Hiển thị 5 nhân viên
- [ ] Sắp xếp theo on-time rate cao nhất

### ✅ Filter "Đi muộn" (Late Arrivals)
- [ ] Hiển thị: Nguyen Van A, Hoang Thi D, Dang Van E (3 nhân viên)
- [ ] Sắp xếp theo tổng phút muộn (descending)
- [ ] Nguyen Van A: 50 phút tổng
- [ ] Hoang Thi D: 60 phút tổng (40+20)
- [ ] Dang Van E: 45 phút tổng (35+10 from 7-day average)

### ✅ Filter "Về sớm" (Early Checkout)
- [ ] Hiển thị: Tran Thi B, Hoang Thi D, Dang Van E (3 nhân viên)
- [ ] Sắp xếp theo tổng phút sớm (descending)
- [ ] Tran Thi B: 105 phút tổng (30+15+60)
- [ ] Hoang Thi D: 45 phút tổng (30+15)
- [ ] Dang Van E: 30 phút tổng

### ✅ Filter "Tốt" (≥80% On-Time)
- [ ] Hiển thị: Pham Van C (1 nhân viên)
- [ ] Pham Van C: 100% on-time rate (7/7)

### ✅ Search Functionality
- [ ] Tìm "Pham" → hiển thị Pham Van C
- [ ] Tìm "Nguyen" → hiển thị Nguyen Van A
- [ ] Tìm "phamvanc" (username) → hiển thị Pham Van C
- [ ] Search + Filter kết hợp → kết quả đúng

### ✅ Date Filters

#### "Hôm nay" (Today)
- [ ] Không có dữ liệu (seed data chạy vào quá khứ)
- [ ] Stat cards hiển thị 0

#### "7 ngày" (7 Days)
- [ ] Hiển thị 35 sessions (5 users × 7 days)
- [ ] Tổng ca: 35
- [ ] Pham Van C: 100% on-time
- [ ] Nguyen Van A: ~57% on-time (4/7)

#### "30 ngày" (30 Days)
- [ ] Hiển thị 57 sessions (35 from Dec + 22 from Nov)
- [ ] Dang Van E dữ liệu lịch sử hiển thị
- [ ] Metrics cập nhật cho tất cả 30 ngày

#### "Tất cả" (All)
- [ ] Tất cả sessions từ database
- [ ] Metrics bao gồm toàn bộ lịch sử

### ✅ Top On-Time Employees Section
- [ ] Hiển thị 5 nhân viên
- [ ] Ranking:
  1. 🥇 Pham Van C - 100%
  2. 🥈 Dang Van E - ~85% (lặp lại)
  3. 🥉 Hoang Thi D - ~57%
  4. #4 Tran Thi B - ~57%
  5. #5 Nguyen Van A - ~57%
- [ ] Hiển thị số ngày làm

### ✅ Admin Stats Cards
- [ ] "Tổng giờ làm (công ty)": ~280h (7 days) hoặc ~476h (30 days)
- [ ] "Tổng ca": 35 (7 ngày) hoặc 57 (30 ngày)
- [ ] "Số lần muộn": 3 (7 ngày) - Nguyen(3) + Hoang(0 in some) + Dang(0 in some)
- [ ] "Số lần về sớm": 3 (7 ngày) - Tran(3) + Hoang(0) + Dang(0)

### ✅ Admin Dashboard Table
- [ ] Bảng nhân viên:
  | Nhân viên | Tổng ca | Đúng giờ | Muộn | Sớm | Trung bình | Trạng thái |
  |----------|--------|---------|-----|-----|-----------|-----------|
  | Pham Van C | 7 | 7 | 0 | 0 | 8.4h | 🟢 Tốt |
  | Dang Van E | 7 | 4-5 | 2 | 1 | ~8h | 🟡 Trung bình |
  | Hoang Thi D | 7 | 4 | 3 | 2 | ~8h | 🟡 Trung bình |
  | Tran Thi B | 7 | 4 | 0 | 3 | ~7.5h | 🟡 Trung bình |
  | Nguyen Van A | 7 | 4 | 3 | 0 | ~8h | 🟡 Trung bình |

### ✅ Staff View (Check-in/out)
- [ ] Nhân viên có thể check-in/out
- [ ] History hiển thị sessions
- [ ] Metrics hiển thị personal performance

### ✅ Edge Cases
- [ ] Late + Overtime: Hoang Thi D ngày 2 (đi muộn 30 phút, kết thúc 17:30 là OT)
- [ ] On-time + Early checkout: Hoang Thi D ngày 3 (đi đúng 08:05, về 16:30)
- [ ] Late + Early: Hoang Thi D ngày 4 (đi muộn 40 phút, về sớm 15 phút)
- [ ] Historical data: Dang Van E có November data cho 30-day filter



