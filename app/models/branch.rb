class Branch < ApplicationRecord
  include SoftDeletable
  
  has_many :users, dependent: :nullify
  has_many :work_shifts, dependent: :destroy
  belongs_to :manager, class_name: 'User', foreign_key: 'manager_id', optional: true
  # Many-to-many managers (nhiều quản lý cùng 1 chi nhánh)
  has_many :branch_manager_records, class_name: 'BranchManager', dependent: :destroy
  has_many :managers, through: :branch_manager_records, source: :user

  validates :name, presence: true, uniqueness: true
  validates :address, presence: true
  
  def as_json(options = {})
    json = super(options)
    json['manager_id'] = manager_id
    json['manager_name'] = manager&.full_name
    json['manager_username'] = manager&.username
    json
  end
end
