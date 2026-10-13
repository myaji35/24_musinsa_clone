class SupplierImportsController < ApplicationController
  def index
    @supplier_imports = SupplierImport.order(created_at: :desc).limit(50)
  end

  def new
    @supplier_import = SupplierImport.new
    @suppliers = Supplier.active.order(:name)
  end

  def create
    @supplier_import = SupplierImport.new(import_params)
    if @supplier_import.save
      if enqueue_import(@supplier_import)
        redirect_to @supplier_import, notice: "상품 입고 파일을 접수했습니다."
      else
        redirect_to @supplier_import, alert: @supplier_import.error_message
      end
    else
      @suppliers = Supplier.active.order(:name)
      flash.now[:alert] = "파일을 확인해 주세요."
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @supplier_import = SupplierImport.find(params[:id])
  end

  def retry
    @supplier_import = SupplierImport.find(params[:id])
    unless @supplier_import.status.in?(%w[pending failed])
      return redirect_to @supplier_import, alert: "다시 처리할 수 없는 상태입니다."
    end

    @supplier_import.update!(status: "pending", error_message: nil)
    if enqueue_import(@supplier_import)
      redirect_to @supplier_import, notice: "상품 입고 파일을 다시 접수했습니다."
    else
      redirect_to @supplier_import, alert: @supplier_import.error_message
    end
  end

  private

  def enqueue_import(import)
    SupplierImportJob.perform_later(import.id)
    true
  rescue SolidQueue::Job::EnqueueError, ActiveRecord::StatementInvalid => e
    Rails.logger.error "상품 입고 작업 등록 실패 (#{import.id}): #{e.class}: #{e.message}"
    import.update!(status: "failed", error_message: "작업 등록 실패(DB 잠김) — 잠시 후 [다시 처리]를 눌러 주세요: #{e.class}")
    false
  end

  def import_params
    params.require(:supplier_import).permit(:supplier_id, :file)
  end
end
