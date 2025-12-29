class Api::V1::AuthController < ApplicationController
  def login
    @user = User.find_by(username: params[:username])
    if @user&.authenticate(params[:password])
      # Tự động fix các ca quên checkout khi user login vào ngày mới
      WorkSession.auto_fix_forgot_checkouts_for_new_day!
      
      token = JsonWebToken.encode(user_id: @user.id)
      render json: { token: token, user: @user.as_json(except: :password_digest) }, status: :ok
    else
      render json: { error: 'Tài khoản hoặc mật khẩu sai' }, status: :unauthorized
    end
  end
end