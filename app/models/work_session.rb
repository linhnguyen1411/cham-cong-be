class WorkSession < ApplicationRecord
  belongs_to :user
  belongs_to :work_shift, optional: true

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

  after_create :assign_shift_and_evaluate_on_time
  before_update :calculate_duration_and_early_checkout, if: :end_time_changed?

  private
  
  def assign_shift_and_evaluate_on_time
    # Sử dụng start_time của session, không phải Time.current
    session_time = start_time.in_time_zone('Bangkok')
    session_hour = session_time.hour
    session_min = session_time.min
    session_minutes = session_hour * 60 + session_min
    
    # Tìm shift phù hợp với thời gian check-in
    matching_shift = find_matching_shift(session_minutes)
    
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
  
  def find_matching_shift(session_minutes)
    # Tìm shift gần nhất mà có start_time <= session time
    matching_shift = nil
    max_shift_minutes = -1
    
    WorkShift.all.each do |shift|
      shift_minutes = time_to_minutes(shift.start_time)
      
      # Shift phải bắt đầu trước hoặc bằng thời gian check-in
      if shift_minutes <= session_minutes && shift_minutes > max_shift_minutes
        matching_shift = shift
        max_shift_minutes = shift_minutes
      end
    end
    
    matching_shift
  end
  
  def calculate_duration_and_early_checkout
    # Tính duration
    if start_time.present? && end_time.present?
      self.duration_minutes = ((end_time - start_time) / 60).to_i
    end
    
    # Nếu không có shift, không kiểm tra early checkout
    return if work_shift.blank?
    
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
end