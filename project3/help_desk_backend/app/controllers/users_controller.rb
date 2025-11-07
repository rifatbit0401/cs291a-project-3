# just for initial testing

class UsersController < ApplicationController
  def register
    if User.exists?(username: user_params[:username])
      render json: { error: "Username already exists" }, status: :conflict
      return
    end

    user = User.new(user_params)
    if user.save
      render json: { message: "User created successfully", user: user }, status: :created
    else
      render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:username, :password)
  end
end
