class SupplierAccountsController < ApplicationController
  def create
    supplier = Supplier.find(params[:supplier_id])
    account = supplier.supplier_accounts.build(params.require(:supplier_account).permit(:email, :name, :password))
    if account.save
      redirect_to supplier, notice: "파트너센터 계정이 발급되었습니다."
    else
      redirect_to supplier, alert: account.errors.full_messages.join(", ")
    end
  end

  def toggle
    supplier = Supplier.find(params[:supplier_id])
    account = supplier.supplier_accounts.find(params[:id])
    account.with_lock { account.update!(active: !account.active?) }
    redirect_to supplier, notice: "계정 상태가 변경되었습니다."
  end
end
