class SessionsController < ApplicationController
  skip_before_action :require_admin

  def new
  end

  def create
    user = User.find_by(email: params[:email].to_s.strip.downcase)

    if user&.password_digest.present? && user.authenticate(params[:password].to_s)
      reset_session
      session[:user_id] = user.id
      redirect_to inventory_scan_path, notice: "로그인되었습니다."
    else
      flash.now[:alert] = "이메일 또는 비밀번호가 올바르지 않습니다."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    reset_session
    redirect_to root_path, status: :see_other, notice: "로그아웃되었습니다."
  end
end
