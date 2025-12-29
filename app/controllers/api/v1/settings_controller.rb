class Api::V1::SettingsController < ApplicationController
  before_action :authorize_request
  before_action :check_admin_permission
  
  def show
    @settings = AppSetting.current
    render json: @settings, status: :ok
  end

  def update
    @settings = AppSetting.current
    params_to_update = settings_params
    
    # Đảm bảo allowed_ips là array (loại bỏ nil và empty strings)
    if params_to_update[:allowed_ips].present?
      params_to_update[:allowed_ips] = Array(params_to_update[:allowed_ips]).reject(&:blank?)
    else
      params_to_update[:allowed_ips] = []
    end
    
    if @settings.update(params_to_update)
      render json: @settings, status: :ok
    else
      render json: { errors: @settings.errors.full_messages }, status: :unprocessable_entity
    end
  end
  
  private
  
  def settings_params
    params.require(:app_setting).permit(
      :company_name, 
      :require_ip_check, 
      :max_user_off_days_per_week,
      :max_user_off_shifts_per_week,
      :max_shift_off_count_per_day,
      allowed_ips: [] # Permit as array - must be at the end
    )
  end
  
  def check_admin_permission
    unless @current_user&.admin?
      render json: { error: 'Chỉ admin mới có quyền thực hiện thao tác này' }, status: :forbidden
    end
  end
end