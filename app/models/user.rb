class User < ApplicationRecord
  include SoftDeletable
  
  has_secure_password
  has_one_attached :avatar
  belongs_to :branch, optional: true
  belongs_to :department, optional: true
  belongs_to :position, optional: true
  belongs_to :role, optional: true
  
  # Many-to-many: user có thể quản lý nhiều branches/departments/positions và ngược lại
  has_many :branch_manager_records, class_name: 'BranchManager', foreign_key: 'user_id', dependent: :destroy
  has_many :managed_branches, through: :branch_manager_records, source: :branch

  has_many :department_manager_records, class_name: 'DepartmentManager', foreign_key: 'user_id', dependent: :destroy
  has_many :managed_departments, through: :department_manager_records, source: :department

  has_many :position_manager_records, class_name: 'PositionManager', foreign_key: 'user_id', dependent: :destroy
  has_many :managed_positions, through: :position_manager_records, source: :position
  
  # Uniqueness validation: chỉ check trong records chưa bị soft delete
  validates :username, presence: true, uniqueness: { 
    case_sensitive: false,
    scope: :deleted_at,
    conditions: -> { where(deleted_at: nil) }
  }
  validates :password, presence: true, length: { minimum: 6 }, on: :create
  validates :password, length: { minimum: 6 }, allow_blank: true, on: :update
  validates :full_name, presence: true
  # Legacy enum: dùng _prefix: :legacy để tránh conflict với belongs_to :role (association)
  # user.role        → Role object (association via role_id)
  # user.legacy_admin? → kiểm tra cột `role` integer = 0
  # Hai cột `role` (integer) và `role_id` (FK) được giữ đồng bộ qua callback sync_legacy_role
  enum role: { admin: 0, staff: 1 }, _prefix: :legacy
  enum work_schedule_type: { both_shifts: 0, morning_only: 1, afternoon_only: 2 }, _default: :both_shifts
  enum status: { active: 0, deactive: 1 }, _default: :active

  before_save :sync_legacy_role

  has_many :work_sessions, dependent: :destroy
  has_many :shift_registrations, dependent: :destroy

  scope :staff, -> { joins(:role).where(roles: { name: 'staff' }).or(where(role_id: nil).where("users.role = ?", 1)) }
  scope :admin, -> { joins(:role).where(roles: { name: ['branch_admin', 'super_admin'] }).or(where(role_id: nil).where("users.role = ?", 0)) }
  scope :active_users, -> { where(status: :active) }
  scope :deactive_users, -> { where(status: :deactive) }
  scope :most_active, -> { joins(:work_sessions).group(:id).order('COUNT(work_sessions.id) DESC') }
  
  # Permission methods

  # Cap 1: Super Admin - Toan quyen global
  def super_admin?
    role&.is_super_admin? || role&.name == 'super_admin'
  end

  # Cap 2: Branch Admin - Quan ly trong chi nhanh duoc chi dinh
  def branch_admin?
    role&.name == 'branch_admin'
  end

  # Cap 3: Department Head - Quan ly team trong bo phan
  def department_head?
    role&.name == 'department_head'
  end
  
  def has_permission?(resource, action)
    return true if super_admin?
    return false unless role
    role.has_permission?(resource, action)
  end
  
  # is_admin? = super_admin hoac branch_admin (co quyen quan ly nhan su)
  def is_admin?
    super_admin? || branch_admin?
  end
  
  def can_create_user_for_department?(department_id)
    return true if super_admin? || is_admin?
    
    # Department manager có thể tạo user cho khối mà mình quản lý
    if department_manager?
      if department_id.present?
        return true if managed_departments.exists?(department_id)
      else
        # Nếu không chỉ định department_id, cho phép tạo trong bất kỳ department nào mà user quản lý
        return true if managed_departments.any?
      end
    end
    
    # Admin hoặc trưởng bộ phận có thể tạo user cho bộ phận của mình (backward compatibility)
    return false unless role
    has_permission?('users', 'create') && (department_id.nil? || self.department_id == department_id)
  end
  
  # Kiểm tra user có thể quản lý (tạo/sửa/xóa) một user khác không
  def can_manage_user?(target_user)
    return true if super_admin? || is_admin?
    return false unless target_user
    
    # Department manager có thể quản lý tất cả users trong khối mà mình quản lý
    if department_manager?
      if target_user.department_id.present?
        return true if managed_departments.exists?(target_user.department_id)
      end
    end
    
    # Position manager có thể quản lý users trong vị trí mà mình quản lý
    if position_manager?
      if target_user.position_id.present?
        return true if managed_positions.exists?(target_user.position_id)
      end
    end
    
    # Branch manager có thể quản lý users trong chi nhánh mà mình quản lý
    if branch_manager?
      if target_user.branch_id.present?
        return true if managed_branches.exists?(target_user.branch_id)
      end
    end
    
    false
  end
  
  # Kiểm tra user có thể quản lý (tạo/sửa/xóa) một position không
  def can_manage_position?(position)
    return true if super_admin? || is_admin?
    return false unless position
    
    # Department manager có thể quản lý positions trong khối mà mình quản lý
    if department_manager?
      if position.department_id.present?
        return true if managed_departments.exists?(position.department_id)
      end
    end
    
    false
  end
  
  # Cap 4: Position Manager - Quan ly nhan vien trong vi tri duoc chi dinh
  def position_manager_role?
    role&.name == 'position_manager'
  end

  # Kiểm tra user có phải là position manager không (qua role hoặc qua assigned positions)
  def position_manager?
    position_manager_role? || managed_positions.any?
  end

  # Kiểm tra user có phải là department manager/head không (kiem tra qua managed_departments)
  def department_manager?
    managed_departments.any?
  end
  alias_method :manages_department?, :department_manager?
  
  # Kiểm tra user có phải là branch manager không
  def branch_manager?
    managed_branches.any?
  end
  
  # Kiểm tra user có thể xem dữ liệu của một user khác không
  def can_view_user?(target_user)
    return true if super_admin? || is_admin?
    return false unless target_user
    
    # Department manager có thể xem users trong khối mà mình quản lý
    if department_manager?
      if target_user.department_id.present?
        return true if managed_departments.exists?(target_user.department_id)
      end
    end
    
    # Position manager có thể xem users trong vị trí mà mình quản lý
    if position_manager?
      if target_user.position_id.present?
        return true if managed_positions.exists?(target_user.position_id)
      end
    end
    
    # Branch manager có thể xem users trong chi nhánh mà mình quản lý
    if branch_manager?
      if target_user.branch_id.present?
        return true if managed_branches.exists?(target_user.branch_id)
      end
    end
    
    false
  end
  
  # Kiểm tra user có thể quản lý một position không (department manager có thể quản lý positions trong department của mình)
  def can_manage_position?(position)
    return true if super_admin? || is_admin?
    return false unless position
    
    # Department manager có thể quản lý positions trong department mà mình quản lý
    if position.department_id.present?
      return true if managed_departments.exists?(position.department_id)
    end
    
    # Position manager có thể quản lý chính position mà mình là manager
    return true if managed_positions.exists?(position.id)
    
    false
  end
  
  # Kiểm tra user có thể quản lý một department không
  def can_manage_department?(department)
    return true if super_admin? || is_admin?
    return false unless department
    managed_departments.exists?(department.id)
  end
  
  # Lấy danh sách user IDs mà user này có thể quản lý
  def manageable_user_ids
    return User.pluck(:id) if super_admin?

    # Branch admin: chi xem users trong chi nhanh minh quan ly
    if branch_admin?
      if managed_branches.any?
        return User.where(branch_id: managed_branches.pluck(:id)).pluck(:id)
      elsif branch_id.present?
        # Fallback: dùng branch_id của chính user này
        return User.where(branch_id: branch_id).pluck(:id)
      else
        # Chưa được gán chi nhánh: chỉ thấy chính mình
        return [id].compact
      end
    end
    
    user_ids = []
    
    # Users trong các positions mà user này quản lý (chỉ active users)
    if managed_positions.any?
      user_ids += User.where(position_id: managed_positions.pluck(:id)).pluck(:id)
    end
    
    # Users trong các departments mà user này quản lý (chỉ active users)
    if managed_departments.any?
      user_ids += User.where(department_id: managed_departments.pluck(:id)).pluck(:id)
    end
    
    # Users trong các branches mà user này quản lý (chỉ active users)
    if managed_branches.any?
      user_ids += User.where(branch_id: managed_branches.pluck(:id)).pluck(:id)
    end
    
    user_ids.uniq
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
  
  private

  # Giữ cột `role` (integer enum) đồng bộ với `role_id` (FK sang bảng roles)
  # Tránh conflict: write_attribute ghi thẳng vào cột, bỏ qua association setter
  def sync_legacy_role
    return unless role_id_changed?

    role_name = self.role&.name
    legacy_value = case role_name
                   when 'super_admin', 'branch_admin' then 0  # map to legacy admin
                   when 'staff', 'department_head', 'department_manager' then 1  # map to legacy staff
                   else
                     role_id.present? ? 1 : read_attribute(:role)  # giữ nguyên nếu không xác định
                   end
    write_attribute(:role, legacy_value)
  end

  public

  def as_json(options = {})
    json = super(options.merge(except: :password_digest))
    json['avatar_url'] = avatar_url
    json['branch_name'] = branch&.name
    json['branch_address'] = branch&.address
    json['department_name'] = department&.name
    json['department_work_days'] = department&.effective_work_days
    json['position_name'] = position&.name
    json['position_level'] = position&.level
    json['role_name'] = role&.name
    json['role_id'] = role_id
    # Manager scopes (for FE to restrict create/update within managed scope)
    json['managed_department_ids'] = managed_departments.pluck(:id)
    json['managed_position_ids'] = managed_positions.pluck(:id)
    json['managed_branch_ids'] = managed_branches.pluck(:id)
    json['managed_branch_names'] = managed_branches.pluck(:name)
    json['managed_department_names'] = managed_departments.pluck(:name)
    json['managed_position_names'] = managed_positions.pluck(:name)
    # Thêm flags để frontend biết user có phải là manager không
    json['is_position_manager'] = position_manager?
    json['is_department_manager'] = department_manager?
    json['is_branch_manager'] = branch_manager?
    # Đơn giản hóa: một flag duy nhất để check quyền quản lý team
    json['can_manage_team'] = is_admin? || position_manager? || department_manager?
    json['is_branch_admin'] = branch_admin?
    json['is_department_head'] = department_head?
    json['is_super_admin'] = super_admin?
    json['is_position_manager_role'] = position_manager_role?
    # RBAC permission keys for frontend ("resource:action")
    json['permissions'] = role&.permissions&.map { |p| "#{p.resource}:#{p.action}" } || []
    json
  end

end