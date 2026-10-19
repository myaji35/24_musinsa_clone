class ApplicationController < ActionController::Base
  before_action :require_admin
  helper_method :current_user, :logged_in?

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id])
  end

  def logged_in?
    current_user.present?
  end

  def require_admin
    return if logged_in?

    session[:return_to] = request.fullpath if request.get? && request.format.html?
    redirect_to login_path, alert: "관리자 로그인이 필요합니다."
  end
end
