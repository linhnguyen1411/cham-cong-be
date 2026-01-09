# app/models/position.rb
class Position < ApplicationRecord
  include SoftDeletable
  
  belongs_to :branch, optional: true
  belongs_to :department, optional: true
  has_many :users, dependent: :nullify
  
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
    super(options).merge(
      'branch_name' => branch&.name,
      'department_name' => department&.name,
      'users_count' => users.count
    )
  end
end

