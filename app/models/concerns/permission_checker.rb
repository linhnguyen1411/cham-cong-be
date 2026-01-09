module PermissionChecker
  extend ActiveSupport::Concern
  
  included do
    before_action :check_permission, except: [:index, :show]
  end
  
  private
  
  def check_permission
    resource = controller_name
    action = action_name
    
    # Map action names to permission actions
    action_map = {
      'create' => 'create',
      'update' => 'update',
      'destroy' => 'delete',
      'approve' => 'approve',
      'reject' => 'reject',
      'bulk_create' => 'create',
      'bulk_approve' => 'approve',
      'admin_update' => 'update',
      'admin_quick_add' => 'create',
      'admin_quick_delete' => 'delete'
    }
    
    permission_action = action_map[action] || action
    
    unless @current_user&.has_permission?(resource, permission_action)
      render json: { error: 'Bạn không có quyền thực hiện thao tác này' }, status: :forbidden
    end
  end
  
  def require_permission(resource, action)
    unless @current_user&.has_permission?(resource, action)
      render json: { error: 'Bạn không có quyền thực hiện thao tác này' }, status: :forbidden
      return false
    end
    true
  end
end

