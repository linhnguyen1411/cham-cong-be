class Api::V1::UsersController < ApplicationController
  before_action :authorize_request
  before_action :check_admin_permission, only: [:create]

  def index
    @users = User.staff.most_active
    render json: @users, status: :ok
  end

  def show
    @user = User.find(params[:id])
    render json: @user, status: :ok
  end

  def create
    @user = User.new(user_params)
    if @user.save
      render json: @user, status: :created
    else
      render json: @user.errors, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:username, :password, :password_confirmation, :full_name, :role)
  end

  def check_admin_permission
    unless @current_user.admin?
      render json: { errors: 'Only admins can perform this action' }, status: :forbidden
    end
  end
end