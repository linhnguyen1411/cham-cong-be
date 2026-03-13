class Department < ApplicationRecord
  include SoftDeletable
  
  has_many :users, dependent: :nullify
  has_many :work_shifts, dependent: :destroy
  belongs_to :manager, class_name: 'User', foreign_key: 'manager_id', optional: true
  belongs_to :branch, optional: true
  # Many-to-many managers
  has_many :department_manager_records, class_name: 'DepartmentManager', dependent: :destroy
  has_many :managers, through: :department_manager_records, source: :user

  validates :name, presence: true, uniqueness: { scope: :branch_id }

  # ip_address: string - IP cho phép checkin của khối
  # Ví dụ: "129.231.1.115"
  
  # work_days: mảng wday của Ruby (0=CN, 1=T2, 2=T3, 3=T4, 4=T5, 5=T6, 6=T7)
  # Mặc định T2-T6 [1,2,3,4,5] nếu không thiết lập
  def effective_work_days
    wd = self[:work_days]
    return [1, 2, 3, 4, 5] if wd.blank?
    wd.map(&:to_i)
  end

  def as_json(options = {})
    json = super(options)
    json['manager_id'] = manager_id
    json['manager_name'] = manager&.full_name
    json['manager_username'] = manager&.username
    json['branch_id'] = branch_id
    json['branch_name'] = branch&.name
    json['work_days'] = effective_work_days
    json
  end
end
