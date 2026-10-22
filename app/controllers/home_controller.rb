class HomeController < ApplicationController
  skip_before_action :require_admin, only: [ :index ]
  def index
    @intro_cache_key = [
      "intro-ring", Character.maximum(:updated_at), Character.count,
      File.mtime(Rails.root.join("config/avatars.yml")).to_f,
      File.mtime(Rails.root.join("config/characters.yml")).to_f
    ]

    @runway_characters = Character.for_intro.select do |character|
      File.exist?(Rails.public_path.join("intro/runway/#{character.handle}.mp4"))
    end

    @products = Product.published.includes(:reviews, :variants, :worn_character).with_attached_image

    # 1. 카테고리(상단 메뉴·아이콘 판): 실제 판매 중인 묶음만
    case params[:category]
    when "아우터" then @products = @products.where(category: "Outer")
    when "코트" then @products = @products.coats
    when "패딩" then @products = @products.paddings
    when "원피스" then @products = @products.one_pieces
    when "신상품" then @products = @products.where(is_new: true)
    when nil, "", "전체" then nil
    else @products = @products.where(category: params[:category])
    end

    # 2. Search (Name or Brand)
    if params[:q].present?
      @products = @products.search_name_or_brand(params[:q])
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
    @stories = params[:q].present? || params[:category].present? ? [] : prepare_stories
  end

  private

  # 유니클로식 홈 리듬: 룩북 사진(같은 상품의 3컷) → 그 묶음 상품 4개
  STORIES = [
    { key: "coat", en: "Wool Coat", title: "울코트", copy: "가을 햇살부터 첫눈까지, 매일 손이 가는 코트", scope: :coats, banner: "JIEUM-G01", category: "코트" },
    { key: "padding", en: "Down & Padding", title: "패딩", copy: "눈 내린 거리도 가볍게, 한겨울을 건강하게", scope: :paddings, banner: "JIEUM-G23", category: "패딩" },
    { key: "night", en: "Night Out", title: "저녁 약속", copy: "벨트 하나로 완성되는 자신감 있는 실루엣", scope: :belted, banner: "JIEUM-G29", category: nil },
    { key: "one-piece", en: "One-piece", title: "원피스", copy: "코트 아래 가장 우아한 한 벌", scope: :one_pieces, banner: "JIEUM-G10", category: "원피스" }
  ].freeze

  def prepare_stories
    Rails.cache.fetch("home-stories", expires_in: 1.hour) do
      STORIES.filter_map do |story|
        products = Product.published.public_send(story[:scope]).includes(:reviews, :variants, :worn_character).with_attached_image
          .order(sales_count: :desc, id: :asc).limit(4).to_a
        next if products.empty?

        banner = Product.published.includes(:worn_character).find_by(supplier_product_code: story[:banner]) || products.first
        story.merge(products: products, banner: banner)
      end
    end
  end
end
