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
end