# app/models/work_shift.rb
class WorkShift < ApplicationRecord
  validates :name, presence: true
  validates :start_time, :end_time, presence: true
  validates :late_threshold, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  
  # Ensure start_time is before end_time
  validate :start_time_before_end_time
  
  private
  
  def start_time_before_end_time
    return if start_time.blank? || end_time.blank?
    
    if start_time >= end_time
      errors.add(:start_time, "must be before end_time")
    end
  end
end