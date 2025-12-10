class AppSetting < ApplicationRecord
  validates :company_name, presence: true
  validates :require_ip_check, presence: true
  validates :allowed_ips, presence: true
end
