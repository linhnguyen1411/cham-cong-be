# 🚀 TimeKeep Pro - Seed Data Setup Guide

## 📋 Tổng Quan

Project này cung cấp seed data hoàn chỉnh để test tất cả các tính năng của TimeKeep Pro Dashboard:
- ✅ Admin metrics & filtering
- ✅ Staff attendance tracking
- ✅ On-time/Late/Early checkout detection
- ✅ Date range filtering (today/month/7days/30days/all)
- ✅ Top employees ranking

## 📁 Files

### 1. `SEED_DATA.md`
Tài liệu chi tiết về seed data, test cases, và expected metrics.

### 2. `db_seeds.rb`
Ruby script để seed database Rails backend (chép vào `db/seeds.rb`).

## 🛠️ Installation & Setup

### Step 1: Copy Seed File
```bash
# From this directory to Rails backend
cp db_seeds.rb /path/to/rails/backend/db/seeds.rb
```

### Step 2: Run Migrations
```bash
cd /path/to/rails/backend
rails db:create
rails db:migrate
```

### Step 3: Seed Database
```bash
rails db:seed
```

Hoặc reset toàn bộ (xóa + tạo mới):
```bash
rails db:seed:replant
```

## 🧪 Test Accounts

### Admin Login
```
Username: admin
Password: 123456
```

### Staff Logins
```
Username: nguyenvana  |  Tran Thi B (Tran Thi B)
Username: tranthib    |  Tran Thi B (Early Checkout)
Username: phamvanc    |  Pham Van C (Perfect Attendance - 100%)
Username: hoangtid    |  Hoang Thi D (Mixed Data)
Username: dangvane    |  Dang Van E (30-Day History)
Password: 123456 (for all)
```

## 📊 Seed Data Summary

### Users Created
- **1 Admin**: admin/123456
- **5 Staff**: 5 different test scenarios

### Work Shifts
- **Ca sáng** (Morning): 08:00-17:00, late_threshold: 30 mins

### Test Scenarios (35-57 Work Sessions)

#### 1️⃣ Pham Van C - Perfect Attendance
- **7 sessions** (7 ngày Dec 2-9)
- All check-in: 08:15, check-out: 17:00
- **Expected**: 100% on-time rate, appears in "Tốt" filter
- **Metrics**: 7/7 on-time, 0 late, 0 early = **100% (🟢 EXCELLENT)**

#### 2️⃣ Nguyen Van A - Late Arrivals
- **7 sessions** (7 ngày Dec 2-9)
- Days 1,2,4,6: On-time (08:10)
- Days 3,5,7: Late (08:45, 09:00, 08:35)
- **Expected**: Appears in "Đi muộn" filter with 50 minutes total
- **Metrics**: 4/7 on-time, 3 late = **~57% (🟡 AVERAGE)**
  - Minutes late: 15 + 30 + 5 = 50 minutes

#### 3️⃣ Tran Thi B - Early Checkouts
- **7 sessions** (7 ngày Dec 2-9)
- Days 1,3,5,7: Normal (08:10, 17:00)
- Days 2,4,6: Early checkout (16:30, 16:45, 16:00)
- **Expected**: Appears in "Về sớm" filter with 105 minutes total
- **Metrics**: 4/7 on-time, 0 late, 3 early = **~57% (🟡 AVERAGE)**
  - Minutes early: 30 + 15 + 60 = 105 minutes

#### 4️⃣ Hoang Thi D - Mixed Data
- **7 sessions** (7 ngày Dec 2-9)
- Complex mix of on-time, late, and early scenarios
- Examples:
  - Day 1: 08:20-17:00 (On-time)
  - Day 2: 09:00-17:30 (30 mins late, but 30 mins OT)
  - Day 3: 08:05-16:30 (On-time, but 30 mins early checkout)
  - Day 4: 09:10-16:45 (40 mins late, 15 mins early checkout)
- **Expected**: Appears in both "Đi muộn" AND "Về sớm" filters
- **Metrics**: 4/7 on-time = **~57% (🟡 AVERAGE)**

#### 5️⃣ Dang Van E - 30-Day History
- **7 sessions** (7 ngày Dec 2-9)
- **22 sessions** (22 ngày Nov 9-30)
- Mixed attendance patterns across months
- **Expected**: Full data for 30-day filter testing
- **Metrics**: ~57% on-time, with historical trend

## 📈 Expected Metrics (After Seeding)

### Admin Dashboard - 7 Days (Dec 2-9)

#### Stats Cards
- **Tổng giờ làm**: ~280 hours (5 users × 7 days ≈ 56 hours/day)
- **Tổng ca**: 35 sessions
- **Số lần muộn**: 3 times (Nguyen: 3, Hoang: varied, Dang: varies)
- **Số lần về sớm**: 3 times (Tran: 3, Hoang: varies, Dang: varies)

#### Filters
| Filter | Count | Users |
|--------|-------|-------|
| Tất cả (All) | 5 | Pham, Nguyen, Tran, Hoang, Dang |
| Đi muộn (Late) | 3 | Nguyen, Hoang*, Dang* |
| Về sớm (Early) | 3 | Tran, Hoang*, Dang* |
| Tốt (≥80%) | 1 | Pham Van C (100%) |

*Hoang & Dang have mixed data depending on date range

#### Top On-Time Employees
1. 🥇 **Pham Van C** - 100% (7/7)
2. 🥈 **Dang Van E** - ~85-90%
3. 🥉 **Hoang Thi D** - ~57-60%
4. #4 **Tran Thi B** - ~57-60%
5. #5 **Nguyen Van A** - ~57-60%

### Admin Dashboard - 30 Days (Nov 9 - Dec 9)

#### Total Sessions
- Dang Van E: 29 sessions (7 Dec + 22 Nov)
- Others: 7 sessions each = **57 total**

#### Expanded Metrics
- **Tổng giờ làm**: ~456 hours
- **Tổng ca**: 57 sessions
- Trends visible across November and December

## 🧪 Testing Workflow

### Recommended Test Order

1. **Test Admin Login**
   ```
   Login as admin/123456
   Should see Admin Dashboard
   ```

2. **Test "Tất cả" Filter**
   - [ ] See 5 staff members
   - [ ] Sorted by on-time rate (highest first)
   - [ ] Pham Van C at top (100%)

3. **Test "Đi muộn" Filter**
   - [ ] See 3 staff: Nguyen, Hoang, Dang
   - [ ] Sorted by minutes late (descending)
   - [ ] Nguyen Van A shows: 50 minutes late total

4. **Test "Về sớm" Filter**
   - [ ] See 3 staff: Tran, Hoang, Dang
   - [ ] Sorted by minutes early (descending)
   - [ ] Tran Thi B shows: 105 minutes early total

5. **Test "Tốt" Filter**
   - [ ] See only Pham Van C
   - [ ] 100% on-time rate
   - [ ] 7 sessions, all on-time

6. **Test Search**
   - [ ] Search "pham" → Pham Van C appears
   - [ ] Search "nguyen" → Nguyen Van A appears
   - [ ] Search works with filters

7. **Test Date Filters**
   - [ ] "7 ngày" → 35 sessions, metrics update
   - [ ] "30 ngày" → 57 sessions, Dang Van E shows history
   - [ ] "Tất cả" → All data from database
   - [ ] "Hôm nay" → No data (seed is historical)

8. **Test Top On-Time Section**
   - [ ] 5 employees ranked by on-time %
   - [ ] Medals for top 3 (🥇 🥈 🥉)
   - [ ] Pham Van C at #1 with 100%

9. **Test Metrics Updates**
   - [ ] Change date filter → all metrics update
   - [ ] Change attendance filter → staff list updates
   - [ ] Search + filter combination → correct results

10. **Test Staff Login**
    ```
    Login as phamvanc/123456
    Should see TimeTracker (check-in/out)
    History should show 7 sessions
    Dashboard shows 100% on-time rate
    ```

## 📝 Seed Script Details

### What Gets Created

#### Users Table
```
ID | Username  | Full Name     | Role  | Password
1  | admin     | Admin User    | admin | 123456
2  | nguyenvana| Nguyen Van A  | staff | 123456
3  | tranthib  | Tran Thi B    | staff | 123456
4  | phamvanc  | Pham Van C    | staff | 123456
5  | hoangtid  | Hoang Thi D   | staff | 123456
6  | dangvane  | Dang Van E    | staff | 123456
```

#### Work Shifts Table
```
ID | Name     | Start Time | End Time | Late Threshold
1  | Ca sáng  | 08:00      | 17:00    | 30 minutes
```

#### Work Sessions Table
- **35 sessions** for 7-day testing (Dec 2-9)
- **57 sessions** total including November history
- Each session includes:
  - user_id
  - start_time (timestamp)
  - end_time (timestamp)
  - duration_minutes
  - date_str (YYYY-MM-DD)
  - work_shift_id
  - is_on_time (boolean)
  - minutes_late (integer)
  - is_early_checkout (boolean)
  - minutes_before_end (integer)

### Helper Functions

```ruby
time_to_minutes(time_str)  # Convert "HH:MM" to minutes from midnight
create_session(...)        # Create a work session with automatic evaluation
```

## 🐛 Troubleshooting

### Seeds won't run
```bash
# Check Rails environment
rails db:migrate RAILS_ENV=development
rails db:seed RAILS_ENV=development

# Or reset everything
rails db:drop db:create db:migrate db:seed
```

### Wrong data showing
```bash
# Clear and reseed
rails db:seed:replant
```

### Check seed output
```bash
# Run with verbose logging
rails db:seed 2>&1 | tee seed.log
```

## 📚 Related Documentation

- `SEED_DATA.md` - Detailed seed data specification
- Rails Models: User, WorkShift, WorkSession (backend)
- Frontend: Dashboard.tsx, AdminDashboard.tsx (React)

## ✅ Success Criteria

After seeding, you should be able to:

- ✅ Login as admin and see 5 staff members on dashboard
- ✅ Filter by attendance type (all/late/early/good)
- ✅ Search for staff by name or username
- ✅ See top on-time employees ranked
- ✅ Change date range and see metrics update
- ✅ Verify metrics match expected values
- ✅ Login as staff and see personal stats
- ✅ Create new check-in/out sessions
- ✅ See all sessions in history

Enjoy testing! 🎉
