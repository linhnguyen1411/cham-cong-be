class Api::V1::SettingsController < ApplicationController
  def show
    @settings = AppSetting.first
    render json: @settings, status: :ok
  end

  def update
    @settings = AppSetting.first
    @settings.update(settings_params)
    render json: @settings, status: :ok
  end
end