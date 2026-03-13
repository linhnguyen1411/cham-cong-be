class Api::V1::UsersController < ApplicationController
  before_action :authorize_request, except: [:avatar]
  # Không cần check_admin_permission nữa, sẽ check trong từng action
  # before_action :check_admin_permission, only: [:create, :deactivate]
  before_action :set_user, only: [:show, :update, :update_password, :update_avatar, :deactivate, :reactivate, :destroy]

  def index
    include_deactive = @current_user&.super_admin? && params[:include_deactive] == 'true'

    if @current_user&.super_admin?
      # Cap 1: Super Admin - xem tat ca users
      base = include_deactive ? User.unscoped.where(deleted_at: nil) : User.active_users
      base = base.where(role_id: params[:role_id]) if params[:role_id].present?
      @users = base.order(created_at: :desc)
    elsif @current_user&.is_admin?
      # Cap 2: Branch Admin - chi xem users trong chi nhanh quan ly
      manageable_ids = @current_user.manageable_user_ids
      base = include_deactive ? User.unscoped.where(deleted_at: nil, id: manageable_ids) : User.active_users.where(id: manageable_ids)
      @users = base.order(created_at: :desc)
    elsif @current_user&.position_manager? || @current_user&.department_manager?
      # Cap 3: Department Head / Position Manager - chi xem trong pham vi quan ly
      manageable_ids = @current_user.manageable_user_ids
      base = include_deactive ? User.unscoped.where(deleted_at: nil, id: manageable_ids) : User.active_users.where(id: manageable_ids)
      @users = base.order(created_at: :desc)
    else
      # Cap 4: Staff - chi xem chinh minh
      @users = [@current_user].compact
    end
    render json: @users, status: :ok
  end
  
  # GET /api/v1/users/my_team
  # Position/Department manager xem danh sách nhân viên trong team
  def my_team
    # Debug: Log user info
    Rails.logger.info "=== my_team (UsersController) Debug ==="
    Rails.logger.info "Current user: #{@current_user&.id} - #{@current_user&.username}"
    Rails.logger.info "Is admin: #{@current_user&.is_admin?}"
    Rails.logger.info "Position manager: #{@current_user&.position_manager?}"
    Rails.logger.info "Department manager: #{@current_user&.department_manager?}"
    Rails.logger.info "Managed positions: #{@current_user&.managed_positions&.count || 0}"
    Rails.logger.info "Managed departments: #{@current_user&.managed_departments&.count || 0}"
    Rails.logger.info "Managed branches: #{@current_user&.managed_branches&.count || 0}"
    
    # Phan quyen theo cap do
    if @current_user&.super_admin?
      manageable_ids = User.pluck(:id)
    elsif @current_user&.is_admin?
      # Branch Admin: chi xem users trong chi nhanh quan ly
      manageable_ids = @current_user.manageable_user_ids
    elsif @current_user&.position_manager? || @current_user&.department_manager?
      # Position/Department manager chỉ xem nhân viên trong phạm vi quản lý
      manageable_ids = @current_user.manageable_user_ids
    else
      # Staff chỉ xem chính mình
      manageable_ids = [@current_user.id].compact
    end
    
    @users = User.where(id: manageable_ids)
      .includes(:position, :department, :branch)
      .order(:full_name)
    
    render json: @users.map { |u|
      u.as_json.merge(
        position_name: u.position&.name,
        department_name: u.department&.name,
        branch_name: u.branch&.name
      )
    }, status: :ok
  end

  def show
    unless @current_user&.super_admin? || @current_user&.is_admin? ||
           @current_user&.can_view_user?(@user) || @current_user&.id == @user.id
      return render_forbidden('Bạn không có quyền xem thông tin người dùng này')
    end
    render json: @user, status: :ok
  end

  def create
    # Super admin và admin có quyền tạo user
    unless @current_user&.super_admin? || @current_user&.is_admin? || @current_user&.department_manager? || @current_user&.position_manager?
      unless check_user_permission('create')
        return
      end
    end

    # Convert user_params to mutable hash
    create_params = user_params.to_h

    # Authorization / scope validation (role hierarchy handled later):
    # - Position manager: validate by managed position (NOT department-based permission)
    # - Department manager: validate by managed department
    # - Others: validate via permission model (department-based)
    department_id = create_params[:department_id]
    position_id = create_params[:position_id]

    if @current_user&.position_manager? && !(@current_user&.super_admin? || @current_user&.is_admin?)
      if position_id.blank? || !@current_user.managed_positions.exists?(id: position_id)
        return render json: { error: 'Bạn chỉ có thể tạo user cho vị trí mà bạn quản lý' }, status: :forbidden
      end
    elsif @current_user&.department_manager? && !(@current_user&.super_admin? || @current_user&.is_admin?)
      # Department manager: bắt buộc phải tạo user thuộc 1 khối mình quản lý (không cho tạo "trôi nổi")
      if department_id.blank? || !@current_user.managed_departments.exists?(id: department_id)
        return render json: { error: 'Bạn chỉ có thể tạo user cho khối/bộ phận mà bạn quản lý' }, status: :forbidden
      end
    else
      # Non-manager: validate via permission model (department scope)
      unless @current_user&.can_create_user_for_department?(department_id)
        return render json: { error: 'Bạn chỉ có thể tạo user cho khối/bộ phận mà bạn quản lý' }, status: :forbidden
      end
    end
    
    # Convert role name to role_id if role is provided as string (for backward compatibility)
    # CHỈ convert nếu role_id chưa được cung cấp - tránh override role_id đúng bằng role string sai
    if create_params.key?(:role) && create_params[:role].is_a?(String) && create_params[:role].present?
      unless create_params[:role_id].present?
        role = Role.find_by(name: create_params[:role])
        create_params[:role_id] = role.id if role
      end
      create_params.delete(:role)
    end
    # Safety: never assign `role` association via string param
    create_params.delete(:role) if create_params.key?(:role)

    # Department head: khong cho tu chon role, luon tao staff
    if @current_user&.department_manager? && !(@current_user&.super_admin? || @current_user&.is_admin?)
      staff_role = Role.find_by(name: 'staff')
      create_params[:role_id] = staff_role&.id if staff_role
    end

    # Branch admin: chi duoc tao user voi role department_head, position_manager hoac staff
    if @current_user&.branch_admin? && create_params[:role_id].present?
      requested_role = Role.find_by(id: create_params[:role_id])
      allowed_roles = ['staff', 'department_head', 'position_manager']
      if requested_role && !allowed_roles.include?(requested_role.name)
        staff_role = Role.find_by(name: 'staff')
        create_params[:role_id] = staff_role&.id  # fallback to staff
      end
    end

    # Branch admin: tu dong gan branch cho user moi tao (neu user chua co branch)
    if @current_user&.branch_admin? && !create_params[:branch_id].present?
      branch_id_to_assign = @current_user.managed_branches.first&.id || @current_user.branch_id
      create_params[:branch_id] = branch_id_to_assign if branch_id_to_assign.present?
    end

    # Position manager: bắt buộc tạo user gắn vào position mình quản lý, và luôn là staff
    if @current_user&.position_manager? && !(@current_user&.super_admin? || @current_user&.is_admin?)
      # position_id has been validated above
      pos = Position.find_by(id: position_id)
      create_params[:department_id] = pos.department_id if pos&.department_id.present?
      create_params[:branch_id] = pos.branch_id if pos&.branch_id.present?

      staff_role = Role.find_by(name: 'staff')
      create_params[:role_id] = staff_role&.id if staff_role
    end
    
    # Ensure role_id is integer if present
    if create_params[:role_id].present?
      create_params[:role_id] = create_params[:role_id].to_i
    end

    # Security: role hierarchy
    # - Cap 1 (super_admin): co the gan bat ky role nao
    # - Cap 2 (branch_admin): chi gan duoc department_head, position_manager va staff
    # - Cap 3+ (department_head, position_manager, staff): khong duoc gan role
    if create_params[:role_id].present?
      requested_role = Role.find_by(id: create_params[:role_id])
      if requested_role
        if requested_role.is_super_admin? && !@current_user&.super_admin?
          return render json: { error: 'Chỉ super admin mới có thể gán vai trò super admin' }, status: :forbidden
        end
        if requested_role.name == 'branch_admin' && !@current_user&.super_admin?
          return render json: { error: 'Chỉ super admin mới có thể gán vai trò Branch Admin' }, status: :forbidden
        end
      end
    end
    
    @user = User.new(create_params)
    if @user.save
      # Tu dong tao lich lam viec cho tuan hien tai neu la staff, department_head hoac position_manager
      staff_role = Role.find_by(name: 'staff')
      dept_head_role = Role.find_by(name: 'department_head')
      pos_manager_role = Role.find_by(name: 'position_manager')
      if [staff_role&.id, dept_head_role&.id, pos_manager_role&.id].include?(@user.role_id) && @user.active?
        create_default_shift_registrations_for_user(@user)
      end

      # position_manager: vị trí được chọn (position_id) = vị trí họ quản lý -> add vào position_managers
      if pos_manager_role && @user.role_id == pos_manager_role.id && @user.position_id.present?
        PositionManager.find_or_create_by(position_id: @user.position_id, user_id: @user.id)
      end

      # department_head: tương tự - khối được chọn (department_id) = khối họ quản lý
      if dept_head_role && @user.role_id == dept_head_role.id && @user.department_id.present?
        DepartmentManager.find_or_create_by(department_id: @user.department_id, user_id: @user.id)
      end

      render json: @user, status: :created
    else
      render json: @user.errors, status: :unprocessable_entity
    end
  end

  # GET /api/v1/users/:id/avatar - Serve avatar directly (public action, no auth required)
  def avatar
    user = User.find_by(id: params[:id])
    
    if user&.avatar&.attached?
      send_data user.avatar.download, 
                type: user.avatar.content_type, 
                disposition: 'inline',
                filename: user.avatar.filename.to_s
    else
      head :not_found
    end
  end

  # PATCH /api/v1/users/:id/deactivate - Deactivate user (set status to deactive)
  def deactivate
    unless @current_user&.super_admin? || @current_user&.is_admin? || @current_user&.can_manage_user?(@user)
      return render json: { error: 'Bạn không có quyền thực hiện thao tác này' }, status: :forbidden
    end

    if @user.update(status: :deactive)
      # Huỷ tất cả shift registrations tương lai (pending + approved) của nhân viên
      cancel_future_shift_registrations(@user)
      render json: { message: 'Đã đánh dấu nhân viên nghỉ việc', user: @user }, status: :ok
    else
      render json: @user.errors, status: :unprocessable_entity
    end
  end

  # PATCH /api/v1/users/:id/reactivate - Reactivate deactive user (super admin only)
  def reactivate
    unless @current_user&.super_admin?
      return render json: { error: 'Chỉ super admin mới có quyền khôi phục tài khoản' }, status: :forbidden
    end

    if @user.update(status: :active)
      render json: { message: 'Đã khôi phục tài khoản nhân viên', user: @user }, status: :ok
    else
      render json: @user.errors, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/users/:id - Soft delete user (deleted_at)
  def destroy
    unless @current_user&.super_admin? || @current_user&.is_admin? || @current_user&.can_manage_user?(@user)
      return render json: { error: 'Bạn không có quyền thực hiện thao tác này' }, status: :forbidden
    end

    if @user.id == @current_user.id
      return render json: { error: 'Không thể xóa chính mình' }, status: :unprocessable_entity
    end

    # Prevent managers from deleting admin/super_admin accounts
    if !(@current_user&.super_admin? || @current_user&.is_admin?) && (@user.super_admin? || @user.is_admin?)
      return render json: { error: 'Không thể xóa tài khoản quản trị' }, status: :forbidden
    end

    @user.destroy
    render json: { message: 'Đã xoá mềm nhân viên', user_id: @user.id }, status: :ok
  end

  # PATCH /api/v1/users/:id - Update profile info
  def update
    unless can_update_user?
      return render json: { error: 'Không có quyền cập nhật thông tin này' }, status: :forbidden
    end
    
    # Manager (dept/branch) không nên được đổi role/role_id hoặc move user ra ngoài scope
    permitted_params =
      if @current_user&.super_admin?
        admin_update_params
      elsif @current_user&.is_admin? || @current_user&.has_permission?('users', 'update')
        # Admin can update fields but cannot change role/role_id (role assignment is super_admin-only)
        manager_update_params
      elsif @current_user&.can_manage_user?(@user)
        manager_update_params
      else
        profile_params
      end
    
    # Convert permitted_params to a mutable hash
    update_params = permitted_params.to_h
    
    # Convert role name to role_id if role is provided as string (for backward compatibility)
    # CHỈ convert nếu role_id chưa được cung cấp - tránh override role_id đúng bằng role string sai
    if update_params.key?(:role) && update_params[:role].is_a?(String) && update_params[:role].present?
      unless update_params[:role_id].present?
        role = Role.find_by(name: update_params[:role])
        update_params[:role_id] = role.id if role
      end
      update_params.delete(:role)
    end
    
    # Ensure role_id is integer if present
    if update_params[:role_id].present?
      update_params[:role_id] = update_params[:role_id].to_i
    end

    # Security: role hierarchy cho update
    # - super_admin: co the thay doi bat ky role nao
    # - branch_admin: chi duoc gan department_head, position_manager va staff
    if update_params[:role_id].present?
      requested_role = Role.find_by(id: update_params[:role_id])
      if requested_role
        if requested_role.is_super_admin? && !@current_user&.super_admin?
          return render json: { error: 'Chỉ super admin mới có thể gán vai trò super admin' }, status: :forbidden
        end
        if requested_role.name == 'branch_admin' && !@current_user&.super_admin?
          return render json: { error: 'Chỉ super admin mới có thể gán vai trò Branch Admin' }, status: :forbidden
        end
      end
    end

    # Manager (dept/branch): strip sensitive fields + validate scope constraints
    if @current_user&.can_manage_user?(@user) && !(@current_user&.super_admin? || @current_user&.is_admin?)
      update_params.delete(:role_id)
      update_params.delete(:role)

      # Không cho update status qua update (dùng endpoint deactivate)
      update_params.delete(:status)

      # Nếu department manager: chỉ được set department_id trong managed_departments
      if @current_user.department_manager?
        if update_params.key?(:department_id) && update_params[:department_id].present?
          unless @current_user.managed_departments.exists?(id: update_params[:department_id])
            return render json: { error: 'Bạn chỉ có thể gán nhân viên vào khối/bộ phận mà bạn quản lý' }, status: :forbidden
          end
        end

        # Nếu có position_id: đảm bảo position thuộc department đang quản lý
        if update_params.key?(:position_id) && update_params[:position_id].present?
          pos = Position.find_by(id: update_params[:position_id])
          if pos && pos.department_id.present? && !@current_user.managed_departments.exists?(id: pos.department_id)
            return render json: { error: 'Bạn chỉ có thể gán vị trí thuộc khối/bộ phận mà bạn quản lý' }, status: :forbidden
          end
        end
      end

      # Nếu position manager: chỉ được set position_id trong managed_positions
      if @current_user.position_manager?
        if update_params.key?(:position_id) && update_params[:position_id].present?
          unless @current_user.managed_positions.exists?(id: update_params[:position_id])
            return render json: { error: 'Bạn chỉ có thể gán nhân viên vào vị trí mà bạn quản lý' }, status: :forbidden
          end
        end
      end
    end
    
    if @user.update(update_params)
      # Cập nhật managed scope (chỉ super_admin và branch_admin mới được làm)
      if @current_user&.super_admin? || @current_user&.is_admin?
        update_managed_scope(@user)
      end
      render json: @user, status: :ok
    else
      render json: @user.errors, status: :unprocessable_entity
    end
  end

  # PATCH /api/v1/users/:id/password - Update password
  def update_password
    unless can_update_user?
      return render json: { error: 'Không có quyền đổi mật khẩu' }, status: :forbidden
    end

    # Verify current password (only if user is updating their own password)
    if @user.id == @current_user.id
      unless @user.authenticate(params[:current_password])
        return render json: { error: 'Mật khẩu hiện tại không đúng' }, status: :unprocessable_entity
      end
    end

    if params[:password].blank? || params[:password].length < 6
      return render json: { error: 'Mật khẩu mới phải có ít nhất 6 ký tự' }, status: :unprocessable_entity
    end

    if @user.update(password: params[:password])
      render json: { message: 'Đổi mật khẩu thành công' }, status: :ok
    else
      render json: @user.errors, status: :unprocessable_entity
    end
  end

  # POST /api/v1/users/:id/avatar - Upload avatar
  def update_avatar
    unless can_update_user?
      return render json: { error: 'Không có quyền cập nhật avatar' }, status: :forbidden
    end

    if params[:avatar].blank?
      return render json: { error: 'Vui lòng chọn ảnh' }, status: :unprocessable_entity
    end

    @user.avatar.attach(params[:avatar])
    
    if @user.avatar.attached?
      render json: { 
        message: 'Cập nhật avatar thành công',
        avatar_url: @user.avatar_url
      }, status: :ok
    else
      render json: { error: 'Không thể upload ảnh' }, status: :unprocessable_entity
    end
  end

  private

  def create_default_shift_registrations_for_user(user)
    today = Date.current
    week_start = today.beginning_of_week(:monday)
    week_end   = today.end_of_week(:monday)   # Sunday

    # Lấy department của user để biết ca làm việc và lịch ngày làm
    department = user.department

    # work_days: ngày làm việc trong tuần (wday 0=CN,1=T2..6=T7)
    work_days = department&.effective_work_days || [1, 2, 3, 4, 5]

    # Ưu tiên ca của khối, nếu không có dùng ca chung (general)
    candidate_shifts = if department && department.work_shifts.exists?
                         department.work_shifts.order(:start_time).to_a
                       else
                         WorkShift.general.order(:start_time).to_a
                       end

    return if candidate_shifts.empty?

    # Dùng toàn bộ ca của khối - không lọc theo work_schedule_type
    # (work_schedule_type chỉ áp dụng cho chế độ cũ sáng/chiều, không phù hợp khi khối có ca tùy chỉnh)
    selected_shifts = candidate_shifts

    return if selected_shifts.empty?

    # Phạm vi ngày: từ HÔM NAY đến HẾT TUẦN (không tạo cho ngày đã qua)
    date_range = (today..week_end).to_a.select { |d| work_days.include?(d.wday) }

    return if date_range.empty?

    existing = ShiftRegistration.where(user_id: user.id, work_date: date_range)
                                .pluck(:work_date, :work_shift_id)
                                .map { |d, sid| "#{d}_#{sid}" }
                                .to_set

    date_range.each do |date|
      selected_shifts.each do |shift|
        next if existing.include?("#{date}_#{shift.id}")
        ShiftRegistration.create!(
          user_id:       user.id,
          work_shift_id: shift.id,
          work_date:     date,
          week_start:    week_start,
          status:        :approved,
          note:          'Tự động tạo khi tạo nhân viên mới'
        )
      end
    end
  rescue => e
    Rails.logger.error "Error creating default shift registrations for user #{user.id}: #{e.message}"
  end

  def cancel_future_shift_registrations(user)
    today = Date.current
    user.shift_registrations
        .where('work_date >= ?', today)
        .where(status: [:pending, :approved])
        .destroy_all
  rescue => e
    Rails.logger.error "Error cancelling shift registrations for user #{user.id}: #{e.message}"
  end

  # Cập nhật managed scope (branches/departments/positions) cho user
  # Chỉ super_admin và branch_admin mới được gọi hàm này
  def update_managed_scope(user)
    # managed_branch_ids: super_admin mới được set
    if params[:user]&.key?(:managed_branch_ids) && @current_user&.super_admin?
      ids = Array(params[:user][:managed_branch_ids]).map(&:to_i).uniq
      user.managed_branches = Branch.where(id: ids)
      # Cập nhật primary manager_id trên branch nếu user là manager duy nhất hoặc được chỉ định
      Branch.where(id: ids).each { |b| b.update_column(:manager_id, user.id) if b.manager_id.nil? }
      # Xóa manager_id trên branches không còn được quản lý bởi user này
      Branch.where(manager_id: user.id).where.not(id: ids).update_all(manager_id: nil)
    end

    # managed_department_ids
    if params[:user]&.key?(:managed_department_ids)
      ids = Array(params[:user][:managed_department_ids]).map(&:to_i).uniq
      # branch_admin chỉ được chỉ định departments trong chi nhánh mình
      if @current_user.branch_admin? && !@current_user.super_admin?
        allowed = Department.where(id: ids, branch_id: @current_user.managed_branches.select(:id)).pluck(:id)
        ids = allowed
      end
      user.managed_departments = Department.where(id: ids)
      Department.where(id: ids).each { |d| d.update_column(:manager_id, user.id) if d.manager_id.nil? }
      Department.where(manager_id: user.id).where.not(id: ids).update_all(manager_id: nil)
    end

    # managed_position_ids
    if params[:user]&.key?(:managed_position_ids)
      ids = Array(params[:user][:managed_position_ids]).map(&:to_i).uniq
      if @current_user.branch_admin? && !@current_user.super_admin?
        allowed = Position.where(id: ids).joins(:department)
                          .where(departments: { branch_id: @current_user.managed_branches.select(:id) })
                          .pluck(:id)
        ids = allowed
      end
      user.managed_positions = Position.where(id: ids)
      Position.where(id: ids).each { |p| p.update_column(:manager_id, user.id) if p.manager_id.nil? }
      Position.where(manager_id: user.id).where.not(id: ids).update_all(manager_id: nil)
    end
  end

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:username, :password, :password_confirmation, :full_name, :role, :role_id, :branch_id, :department_id, :position_id, :work_address, :work_schedule_type)
  end

  def profile_params
    params.require(:user).permit(:full_name, :address, :phone, :birthday, :work_address)
  end

  def admin_update_params
    # Note: role is legacy field (string), but we'll convert it to role_id
    # role_id is the new field for RBAC
    params.require(:user).permit(:full_name, :address, :phone, :birthday, :work_address, :role, :role_id, :branch_id, :department_id, :position_id, :password, :work_schedule_type)
  end

  def manager_update_params
    # Manager chỉ chỉnh thông tin nhân viên + phân công trong phạm vi quản lý.
    # Không cho sửa role/role_id, không cho sửa status (dùng deactivate), không cho đổi username.
    params.require(:user).permit(:full_name, :address, :phone, :birthday, :work_address, :branch_id, :department_id, :position_id, :password, :work_schedule_type)
  end

  def can_update_user?
    # Super admin và admin có thể update bất kỳ ai
    return true if @current_user&.super_admin? || @current_user&.is_admin?
    
    # Department manager có thể update users trong khối mà mình quản lý
    return true if @current_user&.can_manage_user?(@user)
    
    # User chỉ có thể update chính mình
    @current_user.id == @user.id
  end

  def check_admin_permission
    unless @current_user&.has_permission?('users', 'create') || @current_user&.super_admin?
      render json: { errors: 'Only admins can perform this action' }, status: :forbidden
    end
  end
  
  def check_user_permission(action)
    resource = 'users'
    unless @current_user&.has_permission?(resource, action) || @current_user&.super_admin?
      render json: { error: 'Bạn không có quyền thực hiện thao tác này' }, status: :forbidden
      return false
    end
    true
  end
end