# app/models/position.rb
class Position < ApplicationRecord
  include SoftDeletable
  
  belongs_to :branch, optional: true
  belongs_to :department, optional: true
  belongs_to :manager, class_name: 'User', foreign_key: 'manager_id', optional: true
  has_many :users, dependent: :nullify
  # Many-to-many managers
  has_many :position_manager_records, class_name: 'PositionManager', dependent: :destroy
  has_many :managers, through: :position_manager_records, source: :user
  
  validates :name, presence: true
  validates :name, uniqueness: { scope: [:branch_id, :department_id], message: "đã tồn tại trong chi nhánh/phòng ban này" }
  
  # Levels: 0 = nhân viên, 1 = team lead, 2 = trưởng phòng, 3 = giám đốc...
  enum level: { 
    staff_level: 0, 
    team_lead: 1, 
    manager: 2, 
    director: 3,
    executive: 4
  }
  
  scope :by_branch, ->(branch_id) { where(branch_id: branch_id) }
  scope :by_department, ->(dept_id) { where(department_id: dept_id) }
  scope :general, -> { where(branch_id: nil, department_id: nil) }
  
  def full_name
    parts = [name]
    parts << "(#{branch.name})" if branch.present?
    parts << "[#{department.name}]" if department.present?
    parts.join(' ')
  end
  
  def as_json(options = {})
    json = super(options)
    json['branch_name'] = branch&.name
    json['department_name'] = department&.name
    json['users_count'] = users.count
    json['manager_id'] = manager_id
    json['manager_name'] = manager&.full_name
    json['manager_username'] = manager&.username
    json
  end
end

