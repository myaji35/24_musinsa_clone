class SessionsController < ApplicationController
  skip_before_action :require_admin
  rate_limit to: 10, within: 3.minutes, only: :create

  def new
    redirect_to(mall_staff? ? inventory_scan_path : root_path) if logged_in?
  end

  def create
    user = User.find_by(email: params[:email].to_s.strip.downcase)

    if user&.password_digest.present? && user.authenticate(params[:password].to_s)
      if user.suspended?
        flash.now[:alert] = "이용이 정지된 계정입니다. 고객센터로 문의해 주세요."
        render :new, status: :unprocessable_entity
        return
      end

      return_to = session[:return_to]
      cart = session[:cart]
      reset_session
      session[:cart] = cart if cart.present?
      session[:user_id] = user.id
      destination = if mall_staff?
        safe_return_path(return_to) || inventory_scan_path
      elsif current_account && current_account != Account.primary_or_nil
        workspace_path
      else
        safe_return_path(return_to) || root_path
      end
      redirect_to destination, notice: "로그인되었습니다."
    else
      flash.now[:alert] = "이메일 또는 비밀번호가 올바르지 않습니다."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    reset_session
    redirect_to root_path, status: :see_other, notice: "로그아웃되었습니다."
  end

  private

  def safe_return_path(path)
    return unless path.is_a?(String) && path.start_with?("/")
    return if path.start_with?("//", "/\\")

    uri = URI.parse(path)
    return if uri.scheme || uri.host
    return if [ login_path, logout_path ].include?(uri.path.delete_suffix("/"))

    path
  rescue URI::InvalidURIError
    nil
  end
end
