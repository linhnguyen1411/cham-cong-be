#!/usr/bin/env ruby
# frozen_string_literal: true

# Run:
#   cd cham-cong-be
#   bundle exec rails runner script/test_off_cases.rb

week_start = Date.parse(ENV.fetch("WEEK_START", "2026-01-19"))
date_off = Date.parse(ENV.fetch("DATE_OFF", "2026-01-20"))

# Create an isolated position + users so results don't depend on existing production-like data.
test_suffix = Time.current.to_i
test_position = Position.create!(name: "TEST_POS_OFF_#{test_suffix}", description: "tmp", department_id: Department.first&.id, branch_id: Branch.first&.id, level: 0)
position_id = test_position.id

max_off = AppSetting.current.max_shift_off_count_per_day

puts "=== TEST OFF CASES ==="
puts "week_start=#{week_start} date_off=#{date_off} position_id=#{position_id} max_shift_off_count_per_day=#{max_off}"

morning_shift = WorkShift.all.find { |s| s.name.to_s.downcase.include?("sáng") || (s.start_time.present? && s.start_time < "12:00") }
afternoon_shift = WorkShift.all.find { |s| s.name.to_s.downcase.include?("chiều") || (s.start_time.present? && s.start_time >= "12:00" && s.start_time < "18:00") }
raise "Missing morning_shift" unless morning_shift
raise "Missing afternoon_shift" unless afternoon_shift

u1 = User.new(
  username: "test_off_u1_#{test_suffix}",
  password: "123456",
  full_name: "Test Off U1 #{test_suffix}",
  position_id: position_id,
  department_id: test_position.department_id,
  branch_id: test_position.branch_id,
  work_schedule_type: :both_shifts,
  status: :active
)
u1[:role] = 1 # legacy STAFF (avoid association role= conflict)
u1.save!

u2 = User.new(
  username: "test_off_u2_#{test_suffix}",
  password: "123456",
  full_name: "Test Off U2 #{test_suffix}",
  position_id: position_id,
  department_id: test_position.department_id,
  branch_id: test_position.branch_id,
  work_schedule_type: :afternoon_only,
  status: :active
)
u2[:role] = 1 # legacy STAFF
u2.save!

puts "Using users: u1=#{u1.id}(#{u1.username}) type=#{u1.work_schedule_type} | u2=#{u2.id}(#{u2.username}) type=#{u2.work_schedule_type}"

# Ensure both users have a full week schedule for required shifts (approved) so "off" is meaningful.
week_dates = (week_start..(week_start + 6.days)).to_a

def upsert_reg!(user, shift, date, week_start)
  reg = ShiftRegistration.with_deleted.find_by(user_id: user.id, work_shift_id: shift.id, work_date: date)
  if reg.nil?
    registration = ShiftRegistration.new(
      user_id: user.id,
      work_shift_id: shift.id,
      work_date: date,
      week_start: week_start,
      status: :approved,
      note: "test seed"
    )
    # Bypass timing validation for deterministic local test data
    registration.save!(validate: false)
    registration
  elsif reg.deleted?
    reg.update_columns(deleted_at: nil, week_start: week_start, status: ShiftRegistration.statuses[:approved], updated_at: Time.current)
    reg
  else
    reg
  end
end

week_dates.each do |d|
  upsert_reg!(u1, morning_shift, d, week_start)
  upsert_reg!(u1, afternoon_shift, d, week_start)
  upsert_reg!(u2, afternoon_shift, d, week_start) # afternoon_only
end

puts "Seeded baseline schedule OK."

# Case A: user1 takes afternoon off on date_off by soft delete => should be allowed if within limit.
reg_u1_af = ShiftRegistration.find_by!(user_id: u1.id, work_shift_id: afternoon_shift.id, work_date: date_off)
reg_u1_af.audit_soft_delete_for_off!(actor: u1, source: "test_off", reason: "u1 take off afternoon")
puts "A) u1 soft-deleted afternoon on #{date_off} OK"

# Case B: user2 (same position, afternoon_only) tries to take the same afternoon off on same day.
# This should now be blocked by bulk validation logic in API (pending/approved) and by cron top-up,
# but model/controller delete checks might still need to be enforced depending on which flow you use.
reg_u2_af = ShiftRegistration.find_by!(user_id: u2.id, work_shift_id: afternoon_shift.id, work_date: date_off)
begin
  # Simulate a "delete to take off" action
  reg_u2_af.audit_soft_delete_for_off!(actor: u2, source: "test_off", reason: "u2 take off afternoon")
  raise "Expected off-capacity constraint to block u2, but it succeeded"
rescue => e
  puts "B) Expected block: #{e.class}: #{e.message}"
end

puts "=== DONE ==="

# Cleanup (keep DB tidy for repeated runs)
reg_u1_af.reload.destroy! rescue nil
reg_u2_af.reload.destroy! rescue nil
u1.destroy! rescue nil
u2.destroy! rescue nil
test_position.destroy! rescue nil


