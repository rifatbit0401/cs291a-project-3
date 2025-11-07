class AuthController < ApplicationController
    require 'jwt'
    include ActionController::Cookies
    skip_before_action :authenticate_user!, only: [:register, :login, :logout, :refresh, :me]

    SECRET_KEY = Rails.application.secret_key_base
   #  SECRET_KEY = Rails.application.credentials.secret_key_base || "development_secret_key"

    def register
        Rails.logger.info ">>> register action"
        user = User.new(user_params)

        if user.save
            user.update(last_active_at: Time.current)
            ExpertProfile.create!(
            user: user,
            bio: "",
            knowledge_base_links: []
            )
        
        session[:user_id] = user.id  

        token = generate_token(user)

        render json: {
            user: {
            id: user.id,
            username: user.username,
            created_at: user.created_at.iso8601,
            last_active_at: user.last_active_at.iso8601
            },
            token: token
        }, status: :created
        else
        render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
        end
    end
  
    def login
        user = User.find_by(username: params[:username])

        if user&.authenticate(params[:password])
            session[:user_id] = user.id 
            user.update(last_active_at: Time.current)
            token = generate_token(user)

            render json: {
                user: {
                    id: user.id,
                    username: user.username,
                    created_at: user.created_at.iso8601,
                    last_active_at: user.last_active_at.iso8601
                },
                token: token
            }, status: :ok
        else
            render json: { error: "Invalid username or password" }, status: :unauthorized
        end
    end

    # def logout
    #     session.clear
    #      #Explicitly expire the session cookie (Rails test client keeps both if not done)
    #     cookies.delete(
    #         :_help_desk_backend_session,
    #         path: '/',
    #         domain: :all,
    #         same_site: :lax
    #     )

    #     # cookies.delete(:_help_desk_backend_session, domain: :all)
    #     # reset_session
    #     # cookies.delete(Rails.application.config.session_options[:key] || "_help_desk_backend_session")
    #     # request.session_options[:skip] = true
    #     render json: { message: "Logged out successfully" }, status: :ok
    # end

    def logout
        reset_session
        cookies.clear

        render json: { message: "Logged out successfully" }, status: :ok
        end


    def refresh
        if session[:user_id]
            user = User.find_by(id: session[:user_id])

            if user
                user.update(last_active_at: Time.current)
                token = generate_token(user)

                render json: {
                    user: {
                        id: user.id,
                        username: user.username,
                        created_at: user.created_at.iso8601,
                        last_active_at: user.last_active_at.iso8601
                    },
                    token: token
                    }, status: :ok
            else
                render json: { error: "No session found" }, status: :unauthorized
            end
        else
            render json: { error: "No session found" }, status: :unauthorized
        end
    end


    def me
        if session[:user_id]
            user = User.find_by(id: session[:user_id])
            if user
            render json: {
                id: user.id,
                username: user.username,
                created_at: user.created_at.iso8601,
                last_active_at: user.last_active_at&.iso8601
            }, status: :ok
            else
                render json: { error: "No session found" }, status: :unauthorized
        end
        else
            render json: { error: "No session found" }, status: :unauthorized
        end
    end

  private

  def user_params
    params.permit(:username, :password)
  end

  def generate_token(user)
    payload = { user_id: user.id, exp: 24.hours.from_now.to_i }
    JWT.encode(payload, SECRET_KEY)
  end
end
