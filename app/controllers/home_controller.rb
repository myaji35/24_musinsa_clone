class HomeController < ApplicationController
  def index
    @products = Product.all

    # 1. Filter by Category
    if params[:category].present? && params[:category] != "전체"
      # Map Korean categories to English DB values if necessary, or assume DB uses Korean/English mix.
      # Based on seeds, we have "Top", "One-piece". We need to handle this mapping.
      # For now, let's try to match partially or define a mapping.
      # Seed categories: "Top", "One-piece".
      # UI categories: "상의", "아우터", "바지"

      category_map = {
        "상의" => "Top",
        "원피스" => "One-piece",
        "아우터" => "Outer",
        "바지" => "Pants",
        "스커트" => "Skirt",
        "가방" => "Bag"
      }

      db_category = category_map[params[:category]] || params[:category]
      @products = @products.where(category: db_category)
    end

    # 2. Search (Name or Brand)
    if params[:q].present?
      @products = @products.where("name LIKE ? OR brand LIKE ?", "%#{params[:q]}%", "%#{params[:q]}%")
    end

    # 3. Sorting
    case params[:sort]
    when "price_low"
      @products = @products.order(price: :asc)
    when "price_high"
      @products = @products.order(price: :desc)
    when "newest"
      @products = @products.order(created_at: :desc)
    else
      # Default Ranking: Sales Count
      @products = @products.order(sales_count: :desc)
    end

    @ranked_products = @products.limit(50)

    # 29cm 스타일 큐레이션 섹션 준비
    @curated_collections = prepare_curated_collections
  end

  private

  def prepare_curated_collections
    # Low-level caching for curated collections (1 hour expiration)
    Rails.cache.fetch("curated-collections", expires_in: 1.hour) do
      [
        {
          mood: "minimal",
          products: Product.where("ai_attributes LIKE ?", "%minimal%").order(views_count: :desc).limit(10).to_a
        },
        {
          mood: "casual",
          products: Product.where("ai_attributes LIKE ?", "%casual%").order(views_count: :desc).limit(10).to_a
        },
        {
          mood: "delicate",
          products: Product.where("ai_attributes LIKE ?", "%delicate%").order(views_count: :desc).limit(10).to_a
        }
      ].select { |collection| collection[:products].any? }
    end
  end
end
