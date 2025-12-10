# db/seeds.rb - TimeKeep Pro Seed Data
# Run with: rails db:seed

require 'time'

puts "🗑️  Clearing existing data..."
WorkSession.delete_all
WorkShift.delete_all
User.delete_all

puts "👥 Creating users..."

admin = User.create!(
  username: 'admin',
  password: '123456',
  password_confirmation: '123456',
  full_name: 'Admin User',
  role: 'admin'
)

users = {
  'staff01' => 'Nguyen Van A',
  'staff02' => 'Tran Thi B',
  'staff03' => 'Pham Van C',
  'staff04' => 'Hoang Thi D',
  'staff05' => 'Dang Van E',
  'staff06' => 'Ly Thi F',
  'staff07' => 'Ngo Van G',
  'staff08' => 'Trinh Thi H',
  'staff09' => 'Vu Van I',
  'staff10' => 'Bui Thi J',
  'staff11' => 'Cao Van K',
  'staff12' => 'Le Thi L',
  'staff13' => 'Duong Van M',
  'staff14' => 'Phan Thi N',
  'staff15' => 'Ung Van O'
}

staff_users = users.map do |username, full_name|
  User.create!(
    username: username,
    password: '123456',
    password_confirmation: '123456',
    full_name: full_name,
    role: 'staff'
  )
end

puts "✅ Created 1 admin + #{staff_users.length} staff users"

puts "⏰ Creating work shifts..."

morning_shift = WorkShift.create!(
  name: 'Ca sáng',
  start_time: '08:00',
  end_time: '12:00',
  late_threshold: 30
)

afternoon_shift = WorkShift.create!(
  name: 'Ca chiều',
  start_time: '13:00',
  end_time: '17:00',
  late_threshold: 30
)

evening_shift = WorkShift.create!(
  name: 'Ca tối',
  start_time: '18:00',
  end_time: '22:00',
  late_threshold: 30
)

shifts = [morning_shift, afternoon_shift, evening_shift]
puts "✅ Created #{shifts.length} work shifts"

# Helper functions
def time_to_minutes(time_str)
  parts = time_str.split(':')
  parts[0].to_i * 60 + parts[1].to_i
end

def create_session(user, date, check_in_time, check_out_time, shift)
  start_dt = Time.zone.parse("#{date} #{check_in_time}")
  end_dt = Time.zone.parse("#{date} #{check_out_time}")
  
  duration_seconds = (end_dt - start_dt).to_i
  
  # Calculate on-time status
  check_in_minutes = time_to_minutes(check_in_time)
  shift_start_minutes = time_to_minutes(shift.start_time)
  late_threshold = shift.late_threshold
  
  # Minutes late = how many minutes AFTER the allowed time (shift_start + threshold)
  allowed_time_minutes = shift_start_minutes + late_threshold
  minutes_late = [0, check_in_minutes - allowed_time_minutes].max
  is_on_time = (minutes_late == 0)
  
  # Calculate early checkout
  check_out_minutes = time_to_minutes(check_out_time)
  shift_end_minutes = time_to_minutes(shift.end_time)
  minutes_before_end = [0, shift_end_minutes - check_out_minutes].max
  is_early_checkout = (minutes_before_end > 0)
  
  # DEBUG for staff01
  if user.username == 'staff01'
    puts "  [staff01] Date: #{date}, Check-in: #{check_in_time}"
    puts "    check_in_minutes: #{check_in_minutes}"
    puts "    shift_start_minutes: #{shift_start_minutes}"
    puts "    allowed_time_minutes: #{allowed_time_minutes} (shift_start + #{late_threshold})"
    puts "    minutes_late: #{minutes_late}"
    puts "    is_on_time: #{is_on_time}"
  end
  
  WorkSession.create!(
    user: user,
    start_time: start_dt,
    end_time: end_dt,
    duration_minutes: (duration_seconds / 60.0).round(1),
    date: date,
    work_shift: shift,
    is_on_time: is_on_time,
    minutes_late: minutes_late,
    is_early_checkout: is_early_checkout,
    minutes_before_end: minutes_before_end
  )
end

puts "📝 Creating work sessions (75 days, 1 shift/day per staff)..."

today = Date.current
start_date = today - 74
dates_75_days = (start_date..today).map { |d| d.strftime('%Y-%m-%d') }

session_count = 0

staff_users.each_with_index do |user, staff_idx|
  puts "Creating sessions for: #{user.full_name}..."
  
  dates_75_days.each_with_index do |date, day_idx|
    shift = morning_shift
    
    if staff_idx == 0
      # staff01: ALWAYS on-time - check in BEFORE shift start
      # Shift starts at 08:00, threshold is 30 minutes
      # So check-in before 08:00 guarantees on-time
      check_in_offset = [5, 10, 15].sample
      check_in_time = (Time.strptime(shift.start_time, '%H:%M') - check_in_offset.minutes).strftime('%H:%M')
      check_out_time = shift.end_time
    else
      day_pattern = day_idx % 5
      
      if day_pattern < 3  # 60% on-time
        check_in_offset = [5, 10, 15].sample
        check_in_time = (Time.strptime(shift.start_time, '%H:%M') - check_in_offset.minutes).strftime('%H:%M')
        check_out_time = shift.end_time
      elsif day_pattern == 3  # 20% late
        # Check-in AFTER allowed time (08:00 + 30min threshold = 08:30)
        # So check-in at 08:35, 08:40, 08:45, 08:50
        minutes_late = [35, 40, 45, 50].sample
        check_in_time = (Time.strptime(shift.start_time, '%H:%M') + minutes_late.minutes).strftime('%H:%M')
        check_out_time = shift.end_time
      else  # 20% early checkout
        check_in_offset = [5, 10].sample
        check_in_time = (Time.strptime(shift.start_time, '%H:%M') - check_in_offset.minutes).strftime('%H:%M')
        minutes_early = [20, 30, 40].sample
        check_out_time = (Time.strptime(shift.end_time, '%H:%M') - minutes_early.minutes).strftime('%H:%M')
      end
    end
    
    create_session(user, date, check_in_time, check_out_time, shift)
    session_count += 1
  end
end

puts "✅ Created #{session_count} work sessions"

# Verify staff01
staff01 = User.find_by(username: 'staff01')
staff01_sessions = WorkSession.where(user: staff01, is_on_time: true).count
staff01_total = WorkSession.where(user: staff01).count

puts "\n" + "="*60
puts "🎉 SEED DATA COMPLETED!"
puts "="*60

puts "\n📊 Summary:"
puts "  Users: 1 admin + #{staff_users.length} staff"
puts "  Work Shifts: 3 shifts"
puts "  Work Sessions: #{WorkSession.count}"
puts "  Date Range: #{start_date.strftime('%Y-%m-%d')} to #{today.strftime('%Y-%m-%d')} (75 days)"

puts "\n🏆 VERIFICATION:"
puts "  staff01 (Nguyen Van A): #{staff01_sessions}/#{staff01_total} on-time = #{(staff01_sessions.to_f / staff01_total * 100).round}%"
if staff01_sessions == staff01_total
  puts "  ✅ SUCCESS! staff01 has 100% on-time rate"
else
  puts "  ❌ ERROR! staff01 should be 100% on-time"
end

puts "\n👥 Test Accounts:"
puts "  Admin: username='admin', password='123456'"
staff_users.first(3).each_with_index do |user, idx|
  sessions = WorkSession.where(user: user)
  on_time = sessions.where(is_on_time: true).count
  total = sessions.count
  rate = total > 0 ? (on_time.to_f / total * 100).round : 0
  puts "  Staff #{idx + 1}: username='#{user.username}' (#{user.full_name}), on-time: #{rate}%"
end

puts "\n" + "="*60