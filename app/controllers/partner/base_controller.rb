module Partner
  class BaseController < ApplicationController
    skip_before_action :require_admin
    before_action :require_supplier_account
    layout "partner"
    helper_method :current_supplier_account, :current_supplier

    private

    def current_supplier_account
      @current_supplier_account ||= SupplierAccount.find_by(id: session[:supplier_account_id])
    end

    def current_supplier
      current_supplier_account&.supplier
    end

    def require_supplier_account
      return if current_supplier_account&.active? && current_supplier&.active?

      session.delete(:supplier_account_id)
      @current_supplier_account = nil
      redirect_to partner_login_path, alert: "공급사 로그인이 필요합니다."
    end
  end
end
