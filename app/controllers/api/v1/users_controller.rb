class Api::V1::UsersController < ApplicationController
  before_action :authorize_request, except: [:avatar]
  before_action :check_admin_permission, only: [:create]
  before_action :set_user, only: [:show, :update, :update_password, :update_avatar]

  def index
    @users = User.staff.most_active
    render json: @users, status: :ok
  end

  def show
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

  # PATCH /api/v1/users/:id - Update profile info
  def update
    unless can_update_user?
      return render json: { error: 'Không có quyền cập nhật thông tin này' }, status: :forbidden
    end
    
    if @user.update(profile_params)
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

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:username, :password, :password_confirmation, :full_name, :role)
  end

  def profile_params
    params.require(:user).permit(:full_name, :address, :phone, :birthday)
  end

  def can_update_user?
    # Admin can update anyone, user can only update themselves
    @current_user.admin? || @current_user.id == @user.id
  end

  def check_admin_permission
    unless @current_user.admin?
      render json: { errors: 'Only admins can perform this action' }, status: :forbidden
    end
  end
end