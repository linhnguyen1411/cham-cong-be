class Role < ApplicationRecord
  include SoftDeletable
  
  has_many :users, dependent: :nullify
  has_many :role_permissions, dependent: :destroy
  has_many :permissions, through: :role_permissions
  
  validates :name, presence: true, uniqueness: true
  
  scope :system_roles, -> { where(is_system: true) }
  scope :custom_roles, -> { where(is_system: false) }
  scope :super_admin_roles, -> { where(is_super_admin: true) }
  
  # Check if this role is a super admin role
  def is_super_admin?
    is_super_admin == true
  end
  
  def has_permission?(resource, action)
    # Super admin roles have all permissions
    return true if is_super_admin?
    permissions.exists?(resource: resource, action: action)
  end
  
  def add_permission(permission)
    permissions << permission unless permissions.include?(permission)
  end
  
  def remove_permission(permission)
    permissions.delete(permission)
  end
end
