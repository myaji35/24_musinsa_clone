class ProductsController < ApplicationController
  skip_before_action :require_admin, only: [ :index, :show ]
  before_action :set_product, only: [ :show, :edit, :update, :destroy, :publish, :unpublish ]

  def index
    # 관리자(상품 관리)는 초안까지, 손님은 공개 상품만 본다
    @products = logged_in? ? Product.with_attached_image : Product.published.with_attached_image

    @products = @products.includes(:variants)

    # 카테고리 필터
    @products = @products.where(category: params[:category]) if params[:category].present?

    # 브랜드 필터
    @products = @products.where(brand: params[:brand]) if params[:brand].present?

    # 검색
    if params[:q].present?
      @products = @products.search_name_or_brand(params[:q])
    end

    # 정렬
    case params[:sort]
    when "price_asc"
      @products = @products.order(price: :asc)
    when "price_desc"
      @products = @products.order(price: :desc)
    when "popular"
      @products = @products.order(sales_count: :desc)
    else
      @products = @products.order(created_at: :desc)
    end
  end

  def show
    raise ActiveRecord::RecordNotFound unless @product.published? || logged_in?

    @variants = @product.variants
    @selected_variant = @variants.first
    @reviews = @product.reviews.includes(:user).order(created_at: :desc).limit(10)
    @related_products = Product.published.with_attached_image.where(category: @product.category).where.not(id: @product.id).limit(4)
    @pairings = Product.published.with_attached_image.where(supplier_product_code: @product.detail_page["pairings"]) if @product.detail_page&.dig("pairings").present?
    @average_rating = @product.reviews.any? ? (@product.reviews.sum(:rating).to_f / @product.reviews.count).round(1) : 0
  end

  def new
    @product = Product.new
    @product.variants.build
  end

  def create
    @product = Product.new(product_params)
    @product.status = "draft"

    if @product.save
      redirect_to @product, notice: "상품이 성공적으로 등록되었습니다."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    return unless params[:tab] == "inventory"

    @inventory_variants = @product.variants.to_a
    # 전체 이력을 메모리에 올리지 않고 각 옵션의 최신 20건만 조회한다.
    @stock_logs_by_variant = StockLog.where(variant_id: @inventory_variants.map(&:id))
      .where(<<~SQL.squish)
        stock_logs.id IN (
          SELECT recent_logs.id FROM stock_logs AS recent_logs
          WHERE recent_logs.variant_id = stock_logs.variant_id
          ORDER BY recent_logs.created_at DESC, recent_logs.id DESC LIMIT 20
        )
      SQL
      .includes(:variant).recent.order(id: :desc).group_by { |log| log.variant.id }
  end

  def update
    if @product.update(product_params)
      redirect_to @product, notice: "상품이 성공적으로 수정되었습니다."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def publish
    unless @product.publishable?
      return redirect_to @product, alert: "필수 정보가 비어 있어 공개할 수 없습니다: #{@product.publish_blockers.join(', ')}"
    end

    @product.publish!(current_user)
    redirect_to @product, notice: "상세페이지를 공개했습니다. 이제 손님 화면에 보입니다."
  end

  def unpublish
    @product.unpublish!
    redirect_to @product, notice: "비공개로 되돌렸습니다. 관리자 미리보기로만 보입니다."
  end

  def destroy
    @product.destroy
    redirect_to products_url, notice: "상품이 삭제되었습니다."
  end

  private

  def set_product
    @product = Product.find(params[:id])
  end

  def product_params
    params.require(:product).permit(
      :name,
      :description,
      :price,
      :stock,
      :category,
      :brand,
      :gender,
      :image_url,
      :image,
      :worn_character_id,
      :worn_size,
      :runway_video,
      :is_new,
      :restocked_at,
      ai_attributes: {},
      info_notice: Product::INFO_NOTICE_FIELDS,
      badges: [],
      variants_attributes: [ :id, :color, :size, :stock, :min_stock, :barcode, :sku_code, :_destroy ]
    )
  end
end
