class Role < ApplicationRecord
  include SoftDeletable
  
  has_many :users, dependent: :nullify
  has_many :role_permissions, dependent: :destroy
  has_many :permissions, through: :role_permissions
  
  validates :name, presence: true, uniqueness: true
  
  scope :system_roles, -> { where(is_system: true) }
  scope :custom_roles, -> { where(is_system: false) }
  
  def has_permission?(resource, action)
    permissions.exists?(resource: resource, action: action)
  end
  
  def add_permission(permission)
    permissions << permission unless permissions.include?(permission)
  end
  
  def remove_permission(permission)
    permissions.delete(permission)
  end
end
