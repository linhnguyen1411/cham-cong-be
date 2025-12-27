class Api::V1::SettingsController < ApplicationController
  before_action :authorize_request
  before_action :check_admin_permission
  
  def show
    @settings = AppSetting.current
    render json: @settings, status: :ok
  end

  def update
    @settings = AppSetting.current
    if @settings.update(settings_params)
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
      :allowed_ips,
      :max_user_off_days_per_week,
      :max_user_off_shifts_per_week,
      :max_shift_off_count_per_day
    )
  end
  
  def check_admin_permission
    unless @current_user&.admin?
      render json: { error: 'Chỉ admin mới có quyền thực hiện thao tác này' }, status: :forbidden
    end
  end
end