# TimeKeep Pro Seed Data - Quick Reference

## 📌 Files Created

1. **`SEED_SETUP_GUIDE.md`** - Complete setup and testing guide
2. **`SEED_DATA.md`** - Detailed seed data specification
3. **`db_seeds.rb`** - Ruby script for Rails backend (copy to `db/seeds.rb`)

## ⚡ Quick Start

```bash
# In Rails backend directory:
cp /path/to/timekeep-pro/db_seeds.rb db/seeds.rb
rails db:seed
```

## 🔐 Test Accounts

| Username | Password | Role | Description |
|----------|----------|------|-------------|
| admin | 123456 | Admin | View all staff, manage settings |
| phamvanc | 123456 | Staff | ✅ Perfect attendance (100%) |
| nguyenvana | 123456 | Staff | ⚠️ Late arrivals (57% on-time) |
| tranthib | 123456 | Staff | ⏱️ Early checkouts (57% on-time) |
| hoangtid | 123456 | Staff | 🔀 Mixed patterns (57% on-time) |
| dangvane | 123456 | Staff | 📅 30-day history (57% on-time) |

## 📊 Seed Data Overview

### What's Included

- ✅ 1 Admin user
- ✅ 5 Staff users (different scenarios)
- ✅ 1 Work Shift (Ca sáng 08:00-17:00)
- ✅ 35+ Work Sessions (7 days)
- ✅ Additional 22 sessions (November history for 30-day filter)

### Test Scenarios

| User | Scenario | Sessions | Expected Metrics |
|------|----------|----------|------------------|
| Pham Van C | Perfect attendance | 7/7 on-time | 100% (Filter: "Tốt") |
| Nguyen Van A | Late arrivals | 3/7 late | 57%, 50 mins total (Filter: "Đi muộn") |
| Tran Thi B | Early checkouts | 3/7 early | 57%, 105 mins total (Filter: "Về sớm") |
| Hoang Thi D | Mixed patterns | Mixed | 57%, both filters |
| Dang Van E | 30-day history | 7+22 sessions | Trends across months |

## 🎯 Admin Dashboard - Expected Results

### Filters
| Filter | Count | Staff |
|--------|-------|-------|
| Tất cả | 5 | All staff |
| Đi muộn | 3 | Nguyen, Hoang, Dang |
| Về sớm | 3 | Tran, Hoang, Dang |
| Tốt | 1 | Pham Van C |

### Metrics (7 days)
- Total hours: ~280h
- Total sessions: 35
- Late times: 3+ (Nguyen: 3, Hoang: varies, Dang: varies)
- Early checkouts: 3+ (Tran: 3, Hoang: varies, Dang: varies)

### Top On-Time
1. 🥇 Pham Van C - 100%
2. 🥈 Dang Van E - ~85-90%
3. 🥉 Hoang Thi D - ~57%
4. Tran Thi B - ~57%
5. Nguyen Van A - ~57%

## 🧪 Testing Checklist

### Admin View
- [ ] Login with admin/123456
- [ ] See Admin Dashboard with 5 staff
- [ ] "Tất cả" filter shows 5 staff (sorted by on-time % desc)
- [ ] "Đi muộn" filter shows 3 staff with late minutes
- [ ] "Về sớm" filter shows 3 staff with early minutes
- [ ] "Tốt" filter shows only Pham Van C (100%)
- [ ] Search works (try "pham", "nguyen", etc.)
- [ ] Date filters work (7 ngày, 30 ngày, tất cả)
- [ ] Top on-time employees section shows correct ranking
- [ ] Metrics update when changing date filter

### Staff View
- [ ] Login with phamvanc/123456 (or other staff)
- [ ] See TimeTracker page (check-in/out)
- [ ] History page shows 7 sessions
- [ ] Dashboard shows personal metrics
- [ ] Can perform new check-in/out

## 📐 Dates Used

### Current Setup
- **7-day data**: December 2-9, 2025
- **30-day data**: November 9 - December 9, 2025
- **Format**: YYYY-MM-DD

> Note: Seeds use historical dates so "Hôm nay" filter won't show data.

## 🔧 Troubleshooting

### No data showing in admin dashboard?
```bash
# Verify seeds ran successfully
rails console
WorkSession.count  # Should be 57+
User.where(role: 'staff').count  # Should be 5
```

### Reset everything
```bash
rails db:drop
rails db:create
rails db:migrate
rails db:seed
```

### Check specific user's sessions
```bash
rails console
u = User.find_by(username: 'phamvanc')
u.work_sessions.count  # Should be 7
u.work_sessions.where(is_on_time: true).count  # Should be 7
```

## 📖 Documentation Files

| File | Purpose |
|------|---------|
| SEED_SETUP_GUIDE.md | Complete setup + testing workflow |
| SEED_DATA.md | Detailed specs + metrics |
| db_seeds.rb | Rails seed script |
| SEED_DATA_QUICK_REF.md | This file - quick reference |

## ✨ Features to Test

With this seed data, you can test:

- ✅ Admin dashboard with filters
- ✅ Staff search and sorting
- ✅ Attendance tracking (on-time, late, early checkout)
- ✅ Metrics calculation and aggregation
- ✅ Date range filtering (today/month/7days/30days/all)
- ✅ Top employee rankings
- ✅ Mixed scenarios (late+early, overtime, etc.)
- ✅ Historical data (30-day trends)
- ✅ Role-based access (admin vs staff)
- ✅ Check-in/out functionality

## 🎉 You're Ready!

Everything is set up. Now:

1. Copy `db_seeds.rb` to your Rails `db/` folder
2. Run `rails db:seed`
3. Start testing with the accounts above
4. Follow the testing checklist in SEED_SETUP_GUIDE.md

Happy testing! 🚀
