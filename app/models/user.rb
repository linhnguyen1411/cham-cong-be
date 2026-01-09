class User < ApplicationRecord
  include SoftDeletable
  
  has_secure_password
  has_one_attached :avatar
  belongs_to :branch, optional: true
  belongs_to :department, optional: true
  belongs_to :position, optional: true
  belongs_to :role, optional: true
  
  validates :username, presence: true, uniqueness: true
  validates :password, presence: true, length: { minimum: 6 }, on: :create
  validates :password, length: { minimum: 6 }, allow_blank: true, on: :update
  validates :full_name, presence: true
  # Keep old enum for backward compatibility, but prefer role_id
  enum role: { admin: 0, staff: 1 }, _prefix: :legacy
  enum work_schedule_type: { both_shifts: 0, morning_only: 1, afternoon_only: 2 }, _default: :both_shifts
  enum status: { active: 0, deactive: 1 }, _default: :active

  has_many :work_sessions, dependent: :destroy
  has_many :shift_registrations, dependent: :destroy

  scope :staff, -> { joins(:role).where(roles: { name: 'staff' }).or(where(role_id: nil).where("users.role = ?", 1)) }
  scope :admin, -> { joins(:role).where(roles: { name: 'admin' }).or(where(role_id: nil).where("users.role = ?", 0)) }
  scope :active_users, -> { where(status: :active) }
  scope :deactive_users, -> { where(status: :deactive) }
  scope :most_active, -> { joins(:work_sessions).group(:id).order('COUNT(work_sessions.id) DESC') }
  
  # Permission methods
  def super_admin?
    role&.name == 'super_admin'
  end
  
  def has_permission?(resource, action)
    return true if super_admin?
    return false unless role
    role.has_permission?(resource, action)
  end
  
  def can_create_user_for_department?(department_id)
    return true if super_admin?
    return false unless role
    # Admin hoặc trưởng bộ phận có thể tạo user cho bộ phận của mình
    has_permission?('users', 'create') && (department_id.nil? || self.department_id == department_id)
  end

  def total_work_sessions
    work_sessions.count
  end

  def total_work_minutes
    work_sessions.sum(:duration_minutes)
  end
  
  def avatar_url
    if avatar.attached?
      # Use custom endpoint that doesn't require signed verification
      "https://chamcong.minhtranholdings.vn/api/v1/users/#{id}/avatar"
    else
      read_attribute(:avatar_url) # fallback to DB column
    end
  rescue StandardError => e
    Rails.logger.error "Avatar URL error: #{e.message}"
    nil
  end
  
  def as_json(options = {})
    json = super(options.merge(except: :password_digest))
    json['avatar_url'] = avatar_url
    json['branch_name'] = branch&.name
    json['branch_address'] = branch&.address
    json['department_name'] = department&.name
    json['position_name'] = position&.name
    json['position_level'] = position&.level
    json
  end

end