class ApplicationController < ActionController::API
  skip_before_action :verify_authenticity_token, raise: false

  def authorize_request
    header = request.headers['Authorization']
    header = header.split(' ').last if header

    decoded = JsonWebToken.decode(header)

    if decoded
      @current_user = User.find(decoded[:user_id])
    else
      render json: { errors: 'Unauthorized' }, status: :unauthorized
    end
  rescue ActiveRecord::RecordNotFound
    render json: { errors: 'Unauthorized' }, status: :unauthorized
  end

  protected

  # --- Role predicate helpers ---

  def super_admin?
    @current_user&.super_admin? || false
  end

  def is_admin?
    @current_user&.is_admin? || false
  end
  alias_method :admin?, :is_admin?

  def branch_admin?
    @current_user&.branch_admin? || false
  end

  def department_head?
    @current_user&.department_head? || false
  end

  # --- Authorization helpers ---

  # Require super admin. Renders 403 and returns false if not.
  def require_super_admin!
    unless @current_user&.super_admin?
      render_forbidden('Chỉ super admin mới có quyền thực hiện')
      return false
    end
    true
  end

  # Require admin (super_admin OR branch_admin). Renders 403 and returns false if not.
  def require_admin!
    unless @current_user&.is_admin?
      render_forbidden('Chỉ admin mới có quyền thực hiện thao tác này')
      return false
    end
    true
  end

  # RBAC gate: checks role's permission table. super_admin always passes.
  # Returns true if authorized; renders 403 and returns false otherwise.
  def require_permission!(resource, action)
    unless @current_user&.has_permission?(resource, action)
      render_forbidden
      return false
    end
    true
  end

  # Ownership guard: caller must own the resource or be admin/manager of target_user.
  def require_own_or_manage!(target_user)
    return true if @current_user&.super_admin?
    return true if @current_user&.is_admin?
    return true if target_user && @current_user&.can_manage_user?(target_user)
    return true if @current_user&.id == target_user&.id
    render_forbidden('Bạn không có quyền thực hiện thao tác cho người dùng này')
    false
  end

  def render_forbidden(msg = 'Không có quyền thực hiện')
    render json: { error: msg }, status: :forbidden
  end

  # Legacy alias kept for backward compatibility in any remaining inline call sites
  def has_permission?(resource, action)
    @current_user&.has_permission?(resource, action) || false
  end

  def check_user_permission(action)
    unless @current_user&.has_permission?('users', action)
      render json: { error: 'Bạn không có quyền thực hiện thao tác này' }, status: :forbidden
      return false
    end
    true
  end
end
