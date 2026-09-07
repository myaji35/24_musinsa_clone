class ProductsController < ApplicationController
  skip_before_action :require_admin, only: [ :index, :show ]
  before_action :set_product, only: [ :show, :edit, :update, :destroy ]

  def index
    @products = Product.all

    # 카테고리 필터
    @products = @products.where(category: params[:category]) if params[:category].present?

    # 브랜드 필터
    @products = @products.where(brand: params[:brand]) if params[:brand].present?

    # 검색
    if params[:q].present?
      @products = @products.where("name LIKE ? OR brand LIKE ?", "%#{params[:q]}%", "%#{params[:q]}%")
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
    @variants = @product.variants
    @selected_variant = @variants.first
    @reviews = @product.reviews.includes(:user).order(created_at: :desc).limit(10)
    @related_products = Product.where(category: @product.category).where.not(id: @product.id).limit(4)
    @average_rating = @product.reviews.any? ? (@product.reviews.sum(:rating).to_f / @product.reviews.count).round(1) : 0
  end

  def new
    @product = Product.new
    @product.variants.build
  end

  def create
    @product = Product.new(product_params)

    if @product.save
      redirect_to @product, notice: "상품이 성공적으로 등록되었습니다."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @product.update(product_params)
      redirect_to @product, notice: "상품이 성공적으로 수정되었습니다."
    else
      render :edit, status: :unprocessable_entity
    end
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
      :is_new,
      :restocked_at,
      ai_attributes: {},
      badges: [],
      variants_attributes: [ :id, :color, :size, :stock, :min_stock, :barcode, :sku_code, :_destroy ]
    )
  end
end
