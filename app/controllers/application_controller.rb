class ApplicationController < ActionController::Base
  include AccountRequired

  before_action :set_current_context
  before_action :require_admin
  helper_method :current_user, :logged_in?, :cart_count, :magazine_available?, :current_account, :mall_admin?, :supplier_scope

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private

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
    @current_user ||= User.find_by(id: session[:user_id])
  end

  def cart_count
    @cart_count ||= Cart.new(session[:cart] || {}).count
  end

  def logged_in?
    current_user.present?
  end

  def magazine_available?
    return @magazine_available if defined?(@magazine_available)

    @magazine_available = MagazineIssue.visible(admin: mall_admin?).any?
  end

  def current_account
    current_user&.account
  end

  def set_current_context
    Current.user = current_user
    Current.account = current_account
  end

  def mall_admin?
    logged_in? && (current_user.account_id.nil? || current_account == Account.primary_or_nil)
  end

  def require_admin
    return if mall_admin?
    if logged_in?
      redirect_to workspace_path, alert: "이 화면은 몰 관리자 전용입니다"
      return
    end

    session[:return_to] = request.fullpath if request.get? && request.format.html?
    redirect_to login_path, alert: "관리자 로그인이 필요합니다."
  end
end
