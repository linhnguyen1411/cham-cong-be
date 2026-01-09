class Permission < ApplicationRecord
  include SoftDeletable
  
  has_many :role_permissions, dependent: :destroy
  has_many :roles, through: :role_permissions
  
  validates :name, presence: true
  validates :resource, presence: true
  validates :action, presence: true
  validates :resource, uniqueness: { scope: :action, message: "và action đã tồn tại" }
  
  scope :by_resource, ->(resource) { where(resource: resource) }
  scope :by_action, ->(action) { where(action: action) }
  
  def full_name
    "#{resource}:#{action}"
  end
end
