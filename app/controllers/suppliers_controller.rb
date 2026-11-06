# Epic 8.1: 거래처 관리 컨트롤러
class SuppliersController < ApplicationController
  before_action :set_supplier, only: [ :show, :edit, :update, :destroy ]

  def index
    @suppliers = supplier_scope.active.recent
  end

  def show
    @purchase_orders = @supplier.purchase_orders.recent.limit(10)
  end

  def new
    @supplier = supplier_scope.new
  end

  def create
    @supplier = supplier_scope.new(supplier_params)

    if @supplier.save
      redirect_to suppliers_path, notice: "거래처가 등록되었습니다."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @supplier.update(supplier_params)
      redirect_to @supplier, notice: "거래처 정보가 수정되었습니다."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @supplier.update(active: false)
    redirect_to suppliers_path, notice: "거래처가 비활성화되었습니다."
  end

  private

  def set_supplier
    @supplier = supplier_scope.find(params[:id])
  end

  def supplier_scope
    (current_account || Account.primary).suppliers
  end

  def supplier_params
    params.require(:supplier).permit(:name, :contact_person, :phone, :email, :address, :payment_terms, :notes, :active)
  end
end
