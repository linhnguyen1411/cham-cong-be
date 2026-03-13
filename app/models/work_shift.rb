# app/models/work_shift.rb
class WorkShift < ApplicationRecord
  include SoftDeletable
  
  belongs_to :department, optional: true
  belongs_to :position, optional: true
  
  validates :name, presence: true
  validates :start_time, :end_time, presence: true
  validates :late_threshold, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  
  before_validation :normalize_times
  # Ensure start_time is before end_time
  validate :start_time_before_end_time
  # Ensure either department or position is set (or both can be nil for general shifts)
  validate :has_department_or_position

  scope :by_department, ->(dept_id) { where(department_id: dept_id) }
  scope :by_position, ->(position_id) { where(position_id: position_id) }
  scope :general, -> { where(department_id: nil, position_id: nil) }
  
  private

  # Chuẩn hóa start_time / end_time về "HH:MM"
  # Xử lý trường hợp frontend gửi "HH:MM:SS" hoặc chuỗi datetime đầy đủ
  def normalize_times
    self.start_time = extract_hhmm(start_time) if start_time.present?
    self.end_time   = extract_hhmm(end_time)   if end_time.present?
  end

  def extract_hhmm(val)
    str = val.to_s.strip
    # Nếu là ISO datetime, parse và lấy giờ theo múi giờ ứng dụng
    if str.length > 8 && (str.include?('T') || (str.include?('-') && str.include?(':')))
      begin
        t = Time.zone.parse(str) || Time.parse(str)
        return t.strftime('%H:%M')
      rescue
        # fall through
      end
    end
    # "HH:MM:SS" hoặc "HH:MM"
    match = str.match(/\A(\d{1,2}):(\d{2})/)
    match ? "#{match[1].rjust(2, '0')}:#{match[2]}" : str
  end

  def start_time_before_end_time
    return if start_time.blank? || end_time.blank?
    
    if start_time >= end_time
      errors.add(:start_time, "must be before end_time")
    end
  end
  
  def has_department_or_position
    # Allow shifts without department or position (general shifts)
    # But if position is set, it should be valid
    if position_id.present? && position.nil?
      errors.add(:position_id, "is invalid")
    end
  end
end