class WorkSession < ApplicationRecord
  include SoftDeletable
  
  belongs_to :user
  belongs_to :work_shift, optional: true
  belongs_to :shift_registration, optional: true

  scope :filter_by_date, ->(start_date, end_date) {
    where(start_time: start_date.beginning_of_day..end_date.end_of_day)
  }

  scope :filter_by_user, ->(user_id) {
    where(user_id: user_id)
  }

  scope :filter_by_ip, ->(ip_address) {
    where(ip_address: ip_address)
  }

  scope :filter_by_report_mood, ->(report_mood) {
    where(report_mood: report_mood)
  }

  scope :filter_by_handover_notes, ->(handover_notes) {
    where(handover_notes: handover_notes)
  }
  
  scope :active, -> { where(end_time: nil, forgot_checkout: false) }
  scope :forgot_checkout, -> { where(forgot_checkout: true) }

  after_create :assign_shift_and_evaluate_on_time
  before_update :calculate_duration_and_early_checkout, if: :end_time_changed?
  
  # Class method để xử lý các session quên checkout
  def self.process_forgot_checkouts!
    # Chạy vào 2:00 AM mỗi ngày hoặc theo schedule
    timezone = 'Bangkok'
    now = Time.current.in_time_zone(timezone)
    
    # Tìm các session chưa checkout
    unclosed_sessions = where(end_time: nil, forgot_checkout: false)
    
    unclosed_sessions.find_each do |session|
      session.check_forgot_checkout!(now)
    end
  end

  # Class method để tự động fix các ca quên checkout khi vào ngày mới
  # Được gọi khi user login hoặc khi vào ngày mới
  def self.auto_fix_forgot_checkouts_for_new_day!
    timezone = 'Bangkok'
    now = Time.current.in_time_zone(timezone)
    today = now.to_date
    
    fixed_count = 0
    
    # 1. Fix các ca có end_time nhưng thời gian quá dài (quá 02:00 hôm sau)
    where.not(end_time: nil).where.not(start_time: nil).find_each do |session|
      start_time_tz = session.start_time.in_time_zone(timezone)
      end_time_tz = session.end_time.in_time_zone(timezone)
      session_date = start_time_tz.to_date
      
      # Tính thời gian 02:00 hôm sau
      next_day_2am = (session_date + 1.day).in_time_zone(timezone).change(hour: 2, min: 0)
      
      # Nếu end_time quá 02:00 hôm sau thì coi như quên checkout
      if end_time_tz > next_day_2am
        # Set end_time = nil (coi như trống ca, không tính vào ca hoàn thành)
        session.update!(
          end_time: nil,
          duration_minutes: nil,
          forgot_checkout: true,
          is_early_checkout: false,
          minutes_before_end: 0
        )
        fixed_count += 1
      end
    end
    
    # 2. Fix các ca chưa checkout và đã qua ngày mới (02:00 hôm sau)
    where(end_time: nil, forgot_checkout: false).find_each do |session|
      session_date = session.start_time.in_time_zone(timezone).to_date
      next_day_2am = (session_date + 1.day).in_time_zone(timezone).change(hour: 2, min: 0)
      
      # Nếu đã qua 02:00 hôm sau thì mark forgot_checkout (end_time vẫn là nil)
      if now >= next_day_2am
        session.mark_forgot_checkout!
        fixed_count += 1
      end
    end
    
    fixed_count
  end
  
  def check_forgot_checkout!(current_time = Time.current.in_time_zone('Bangkok'))
    return if end_time.present? || forgot_checkout?
    
    session_date = start_time.in_time_zone('Bangkok').to_date
    
    # Case 1: Nếu đã qua 2:00 AM của ngày hôm sau
    next_day_2am = (session_date + 1.day).in_time_zone('Bangkok').change(hour: 2, min: 0)
    if current_time >= next_day_2am
      mark_forgot_checkout!
      return
    end
    
    # Case 2: Nếu có ca làm và đã quá giờ kết thúc ca + 4 tiếng (buffer)
    if work_shift.present?
      shift_end_time = parse_shift_time(work_shift.end_time, session_date)
      buffer_time = shift_end_time + 4.hours
      
      if current_time >= buffer_time
        mark_forgot_checkout!
        return
      end
    end
  end
  
  def mark_forgot_checkout!
    # Nếu quên checkout thì coi như trống ca ngày hôm đó (end_time = nil)
    # Không tính vào ca hoàn thành trong báo cáo
    update!(
      forgot_checkout: true,
      end_time: nil,
      duration_minutes: nil,
      is_early_checkout: false,
      minutes_before_end: 0
    )
  end

  private
  
  def assign_shift_and_evaluate_on_time
    # Sử dụng start_time của session, không phải Time.current
    session_time = start_time.in_time_zone('Bangkok')
    session_hour = session_time.hour
    session_min = session_time.min
    session_minutes = session_hour * 60 + session_min
    session_date = session_time.to_date
    
    # Ưu tiên 1: Kiểm tra xem có đăng ký ca cho ngày này không
    approved_registration = find_approved_registration(session_date)
    
    if approved_registration.present?
      self.shift_registration = approved_registration
      matching_shift = approved_registration.work_shift
    else
      # Ưu tiên 2: Tìm ca gần nhất với thời gian check-in
      matching_shift = find_nearest_shift(session_minutes)
    end
    
    return if matching_shift.blank?
    
    # Gán shift
    self.work_shift = matching_shift
    
    # Tính toán on-time status
    shift_start_minutes = time_to_minutes(matching_shift.start_time)
    allowed_time_minutes = shift_start_minutes + matching_shift.late_threshold
    
    # Số phút muộn = check-in AFTER allowed time
    minutes_late_value = [0, session_minutes - allowed_time_minutes].max
    
    self.minutes_late = minutes_late_value
    # QUAN TRỌNG: Chỉ đúng giờ khi minutes_late == 0
    self.is_on_time = (minutes_late_value == 0)
    
    save
  end
  
  def find_approved_registration(date)
    user.shift_registrations.approved_only.for_date(date).first
  end
  
  def find_nearest_shift(session_minutes)
    # Tìm ca gần nhất với thời gian check-in (có thể trước hoặc sau)
    nearest_shift = nil
    min_distance = Float::INFINITY
    
    # Lấy các ca làm việc của department mà user thuộc về
    shifts = if user&.department_id.present?
      WorkShift.where(department_id: [user.department_id, nil])
    else
      WorkShift.where(department_id: nil)
    end
    
    shifts.each do |shift|
      shift_start_minutes = time_to_minutes(shift.start_time)
      shift_end_minutes = time_to_minutes(shift.end_time)
      
      # Tính khoảng cách đến ca này
      # Nếu đang trong khoảng ca -> distance = 0
      if session_minutes >= shift_start_minutes && session_minutes <= shift_end_minutes
        distance = 0
      elsif session_minutes < shift_start_minutes
        # Check-in trước giờ bắt đầu ca
        distance = shift_start_minutes - session_minutes
      else
        # Check-in sau giờ kết thúc ca
        distance = session_minutes - shift_end_minutes
      end
      
      if distance < min_distance
        min_distance = distance
        nearest_shift = shift
      end
    end
    
    # Chỉ chấp nhận nếu check-in trong khoảng hợp lý (trước 2h hoặc sau 4h so với giờ bắt đầu)
    if nearest_shift.present?
      shift_start = time_to_minutes(nearest_shift.start_time)
      # Cho phép check-in sớm 2h hoặc muộn 4h
      if session_minutes >= (shift_start - 120) && session_minutes <= (shift_start + 240)
        return nearest_shift
      end
    end
    
    # Fallback: Trả về ca đầu tiên nếu không tìm được ca phù hợp
    nil
  end
  
  def calculate_duration_and_early_checkout
    # Tính duration
    if start_time.present? && end_time.present?
      self.duration_minutes = ((end_time - start_time) / 60).to_i
    else
      # Nếu end_time là nil, set duration_minutes = nil
      self.duration_minutes = nil
    end
    
    # Nếu không có shift hoặc không có end_time, không kiểm tra early checkout
    return if work_shift.blank? || end_time.blank?
    
    # Sử dụng end_time của session, không phải Time.current
    checkout_time = end_time.in_time_zone('Bangkok')
    checkout_minutes = checkout_time.hour * 60 + checkout_time.min
    
    shift_end_minutes = time_to_minutes(work_shift.end_time)
    
    # Số phút checkout trước giờ kết thúc
    minutes_before_end_value = shift_end_minutes - checkout_minutes
    
    if minutes_before_end_value > 0
      # Checkout sớm
      self.is_early_checkout = true
      self.minutes_before_end = minutes_before_end_value
    else
      # Checkout đúng giờ hoặc muộn
      self.is_early_checkout = false
      self.minutes_before_end = 0
    end
  end
  
  def time_to_minutes(time_str)
    parts = time_str.split(':')
    parts[0].to_i * 60 + parts[1].to_i
  end
  
  def parse_shift_time(time_str, date)
    parts = time_str.split(':')
    date.in_time_zone('Bangkok').change(hour: parts[0].to_i, min: parts[1].to_i)
  end
end
