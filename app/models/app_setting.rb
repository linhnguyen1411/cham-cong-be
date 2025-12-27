class AppSetting < ApplicationRecord
  validates :company_name, presence: true
  validates :require_ip_check, inclusion: { in: [true, false] }
  validate :allowed_ips_is_array
  
  validates :max_user_off_days_per_week, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :max_user_off_shifts_per_week, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :max_shift_off_count_per_day, presence: true, numericality: { only_integer: true, greater_than: 0 }
  
  private
  
  def allowed_ips_is_array
    if allowed_ips.nil?
      errors.add(:allowed_ips, "can't be blank")
    elsif !allowed_ips.is_a?(Array)
      errors.add(:allowed_ips, "must be an array")
    end
  end
  
  # Class method to get settings (singleton pattern)
  def self.current
    setting = first
    if setting.nil?
      # Tạo mới với giá trị mặc định
      setting = create!(
        company_name: 'Minh Trần Holdings',
        require_ip_check: false,
        allowed_ips: [],
        max_user_off_days_per_week: 1,
        max_user_off_shifts_per_week: 2,
        max_shift_off_count_per_day: 1
      )
    end
    setting
  end
end
