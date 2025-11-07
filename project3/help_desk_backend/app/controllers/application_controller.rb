class ApplicationController < ActionController::API
  before_action :authenticate_user!

  

  private

  def authenticate_user!
    header = request.headers['Authorization']
    Rails.logger.info "AUTH HEADER RECEIVED: #{header.inspect}"

    if header.blank?
      return render json: { error: 'Missing Authorization header' }, status: :unauthorized
    end

    token = header.split(' ').last
    begin
      decoded = JWT.decode(token, Rails.application.secret_key_base, true, algorithm: 'HS256')
      @current_user = User.find(decoded[0]['user_id'])
    rescue JWT::ExpiredSignature
      render json: { error: 'Token has expired' }, status: :unauthorized
    rescue JWT::DecodeError => e
      render json: { error: "Invalid token: #{e.message}" }, status: :unauthorized
    end
  end
end
