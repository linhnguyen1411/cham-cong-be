# 📋 TimeKeep Pro Seed Data Documentation

Dự án này bao gồm seed data hoàn chỉnh để test tất cả tính năng của TimeKeep Pro Dashboard.

## 📁 Documentation Files

### 1. **SEED_DATA_QUICK_REF.md** ⚡ (Bắt Đầu Tại Đây)
Quick reference với:
- Test accounts (username/password)
- Seed data overview
- Expected results
- Testing checklist

**👉 Start here for quick setup**

### 2. **SEED_SETUP_GUIDE.md** 📖 (Hướng Dẫn Chi Tiết)
Complete guide với:
- Installation steps
- Detailed test scenarios
- Expected metrics breakdown
- Troubleshooting
- Full testing workflow

**👉 Use this for comprehensive testing**

### 3. **SEED_DATA.md** 📊 (Đặc Tả Kỹ Thuật)
Technical specification với:
- Seed data structure
- All test cases
- Metrics calculations
- Test matrix

**👉 Reference for technical details**

### 4. **db_seeds.rb** 🛠️ (Ruby Script)
Rails seed script tạo tất cả dữ liệu.

**👉 Copy to `db/seeds.rb` in Rails backend**

## 🚀 Quick Start (5 Phút)

```bash
# 1. Copy seed script
cp db_seeds.rb /path/to/rails/app/db/seeds.rb

# 2. Run migrations
cd /path/to/rails/app
rails db:migrate

# 3. Seed database
rails db:seed

# 4. Start Rails server
rails s -p 3000
```

## 🔐 Test Accounts

```
Admin:     admin / 123456
Staff:     phamvanc / 123456    (Perfect: 100% on-time)
           nguyenvana / 123456  (Late: 3/7 sessions)
           tranthib / 123456    (Early: 3/7 sessions)
           hoangtid / 123456    (Mixed)
           dangvane / 123456    (30-day history)
```

## 📊 What Gets Seeded

- **Users**: 1 admin + 5 staff
- **Shifts**: 1 shift (Ca sáng 08:00-17:00)
- **Sessions**: 35+ work sessions (7 days) + 22 historical (November)

## ✅ Test Coverage

Seed data covers:

- ✅ Admin dashboard with all filters
- ✅ Staff filtering and search
- ✅ Attendance tracking (on-time, late, early)
- ✅ Metrics calculation
- ✅ Date range filters
- ✅ Top employee rankings
- ✅ Mixed scenarios
- ✅ Historical data
- ✅ Role-based views

## 📈 Expected Dashboard Results

### Admin View - Filters
| Filter | Staff | Metrics |
|--------|-------|---------|
| Tất cả | 5 | All users |
| Đi muộn | 3 | Nguyen (50 mins), Hoang, Dang |
| Về sớm | 3 | Tran (105 mins), Hoang, Dang |
| Tốt | 1 | Pham Van C (100%) |

### Top On-Time Employees
1. 🥇 Pham Van C - 100%
2. 🥈 Dang Van E - ~85-90%
3. 🥉 Hoang Thi D - ~57%
4. Tran Thi B - ~57%
5. Nguyen Van A - ~57%

## 🧪 Test Scenarios

### 1. Perfect Attendance (Pham Van C)
- 7 sessions, all on-time (08:15)
- Should appear in "Tốt" filter with 100% rate

### 2. Late Arrivals (Nguyen Van A)
- 3 late sessions: 15, 30, 5 minutes
- Should appear in "Đi muộn" filter with 50 mins total

### 3. Early Checkouts (Tran Thi B)
- 3 early sessions: 30, 15, 60 minutes
- Should appear in "Về sớm" filter with 105 mins total

### 4. Mixed Patterns (Hoang Thi D)
- Combination of late + early scenarios
- Should appear in both "Đi muộn" and "Về sớm" filters

### 5. 30-Day History (Dang Van E)
- 7 sessions (December) + 22 sessions (November)
- For testing date range filters

## 🎯 Testing Workflow

1. **Setup Database** (see Quick Start above)
2. **Login as Admin** - See dashboard with 5 staff
3. **Test Filters** - Try each filter button
4. **Test Search** - Search by name/username
5. **Test Date Filters** - Switch between time ranges
6. **Test Staff Login** - Check personal dashboard
7. **Verify Metrics** - Compare with expected values

## 📚 File Map

```
timekeep-pro/
├── SEED_DATA_QUICK_REF.md     ⭐ Start here
├── SEED_SETUP_GUIDE.md        📖 Full guide
├── SEED_DATA.md               📊 Technical specs
└── db_seeds.rb                🛠️ Rails script
```

## 🔧 Common Commands

```bash
# Run seeds
rails db:seed

# Reset everything (careful!)
rails db:drop db:create db:migrate db:seed

# Check what was created
rails console
User.count
WorkSession.count
WorkShift.count

# View specific user's data
User.find_by(username: 'phamvanc').work_sessions.count
```

## ❓ FAQ

### Q: Where do I put db_seeds.rb?
A: Copy to `db/seeds.rb` in your Rails application.

### Q: Can I run seeds multiple times?
A: Yes, it will delete and recreate data each time.

### Q: What if I see duplicate data?
A: Run `rails db:drop db:create db:migrate db:seed` to reset.

### Q: How do I test a specific scenario?
A: Check SEED_DATA.md for detailed case descriptions.

### Q: What if metrics don't match expected?
A: Check SEED_SETUP_GUIDE.md troubleshooting section.

## 📞 Support

For detailed information:
- **Quick reference**: See SEED_DATA_QUICK_REF.md
- **Setup issues**: See SEED_SETUP_GUIDE.md → Troubleshooting
- **Technical details**: See SEED_DATA.md
- **Script details**: See comments in db_seeds.rb

## ✨ Next Steps

1. ✅ Read SEED_DATA_QUICK_REF.md (this takes 2 minutes)
2. ✅ Run Quick Start commands
3. ✅ Login and explore dashboard
4. ✅ Follow testing checklist in SEED_SETUP_GUIDE.md
5. ✅ Verify all filters and features work

Enjoy testing! 🚀
