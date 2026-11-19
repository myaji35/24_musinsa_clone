class ApplicationController < ActionController::Base
  include AccountRequired
  include TrafficSourceTracking

  before_action :set_current_context
  before_action :require_admin
  helper_method :current_user, :logged_in?, :cart_count, :magazine_available?, :current_account, :mall_admin?, :mall_staff?, :supplier_scope, :tenant_member?

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private

  def safe_return_path(path)
    return unless path.is_a?(String) && path.start_with?("/")
    return if path.start_with?("//", "/\\")

    uri = URI.parse(path)
    return if uri.scheme || uri.host
    return if [ login_path, logout_path, join_path ].include?(uri.path.delete_suffix("/"))

    path
  rescue URI::InvalidURIError
    nil
  end

  def supplier_scope
    (current_account || Account.primary).suppliers
  end

  def supplier_in_account?(record)
    return true if record.supplier_id.blank? || supplier_scope.exists?(id: record.supplier_id)

    record.errors.add(:supplier_id, "는 이 계정의 거래처여야 합니다")
    false
  end

  def normalize_search_query
    params[:q] = params[:q].strip if params[:q].is_a?(String)
  end

  def current_user
    @current_user ||= begin
      user = User.find_by(id: session[:user_id])
      if user&.suspended?
        reset_session
        nil
      else
        user
      end
    end
  end

  def cart_count
    @cart_count ||= Cart.new(session[:cart] || {}).count
  end

  def logged_in?
    current_user.present?
  end

  def magazine_available?
    return @magazine_available if defined?(@magazine_available)

    @magazine_available = MagazineIssue.visible(admin: mall_staff?).any?
  end

  def current_account
    current_user&.account
  end

  def tenant_member?
    current_account && current_account != Account.primary_or_nil
  end

  def set_current_context
    Current.user = current_user
    Current.account = current_account
  end

  def mall_admin?
    logged_in? && current_user.admin?
  end

  def mall_staff?
    logged_in? && current_user.staff?
  end

  def require_login
    return if logged_in?

    session[:return_to] = request.fullpath if request.get? && request.format.html?
    redirect_to login_path, alert: "로그인이 필요합니다."
  end

  def require_staff
    return if mall_staff?

    deny_access("이 화면은 관리자 전용입니다")
  end

  def require_admin
    return if mall_admin?

    deny_access("이 화면은 관리자 전용입니다")
  end

  def deny_access(message)
    unless logged_in?
      session[:return_to] = request.fullpath if request.get? && request.format.html?
      redirect_to login_path, alert: "로그인이 필요합니다."
      return
    end

    if current_user.operator?
      redirect_to inventory_scan_path, alert: message
    elsif current_account && current_account != Account.primary_or_nil
      redirect_to workspace_path, alert: "이 화면은 몰 관리자 전용입니다"
    else
      redirect_to root_path, alert: "접근 권한이 없습니다."
    end
  end
end
