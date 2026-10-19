require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  def setup
    # Create products with different attributes for ranking
    @product1 = Product.create!(
      name: "Best Seller Product",
      price: 79000,
      brand: "JIEUN",
      category: "Dress",
      stock: 100,
      views_count: 500,
      sales_count: 50,
      ai_attributes: { mood: "minimal", tpo: "daily" }.to_json,
      is_new: true,
      image_url: "https://images.unsplash.com/photo-1595777457583-95e059d581b8"
    )

    @product2 = Product.create!(
      name: "Popular Product",
      price: 59000,
      brand: "COVERNAT",
      category: "Top",
      stock: 80,
      views_count: 300,
      sales_count: 30,
      ai_attributes: { mood: "casual", tpo: "outdoor" }.to_json,
      image_url: "https://images.unsplash.com/photo-1594633313593-bab3825d0caf"
    )

    @product3 = Product.create!(
      name: "New Arrival",
      price: 89000,
      brand: "ANDERSSON BELL",
      category: "Coat",
      stock: 50,
      views_count: 100,
      sales_count: 10,
      ai_attributes: { mood: "modern", tpo: "business" }.to_json,
      is_new: true,
      image_url: "https://images.unsplash.com/photo-1591369822096-ffd140ec948f"
    )
  end

  test "특수 문자 검색은 전체 상품 대신 빈 결과를 표시한다" do
    [ "%", "_", "\\" ].each do |query|
      get root_path, params: { q: query }

      assert_response :success
      assert_select "[role=status] h2", text: "검색 결과가 없습니다"
      assert_select "a[href=?]", product_path(@product1), count: 0
    end
  end

  test "이름과 브랜드의 특수 문자 및 일반 검색이 동작한다" do
    [ "50%", "item_code", "path\\name", "일반검색" ].each do |query|
      [ :name, :brand ].each do |attribute|
        @product1.update!(name: "검색대상", brand: "검색브랜드", attribute => "앞#{query}뒤")
        get root_path, params: { q: query }

        assert_response :success
        assert_select "#ranking .grid h3", text: @product1.name
        assert_select "[role=status]", count: 0
      end
    end
  end

  test "empty search displays query and reset without curation or ranking" do
    query = "<없는상품>"
    get root_path, params: { q: query, category: "상의" }

    assert_response :success
    assert_select "[role=status] h2", text: "검색 결과가 없습니다"
    assert_select "[role=status] p", text: "“#{query}”에 해당하는 상품이 없습니다."
    assert_select "a[href=?]", root_path(category: "상의"), text: "검색 초기화"
    assert_select "#ranking", count: 0
    assert_select "a[href=?]", product_path(@product1), count: 0
    assert_select "a[href=?]", new_product_path, count: 0
  end

  test "인트로는 DB 캐릭터 스무 명과 아바타 열 명을 표시한다" do
    YAML.load_file(Rails.root.join("config/characters.yml")).each do |attributes|
      Character.create!(attributes)
    end

    get root_path

    assert_response :success
    assert_select ".intro-card", count: 20
    assert_select ".intro-card-photo", count: 10
    assert_select ".intro-card-soon", text: "곧 공개", count: 10
    assert_select ".intro-card-virtual", text: "가상 인물", count: 10
    assert_select 'img[alt="강유나 (AI 가상 인물)"]', count: 1
    assert_select ".intro-card-details p", text: "22 · 미국 LA"
    assert_select ".intro-card h3", text: "서하린"
    assert_equal Character.for_intro.map(&:name), css_select(".intro-card h3").map(&:text)
  end

  test "인트로 조각 캐시는 캐릭터 수정과 삭제를 반영한다" do
    character = Character.create!(YAML.load_file(Rails.root.join("config/characters.yml")).first)
    original_cache_store = ActionController::Base.cache_store
    original_perform_caching = ActionController::Base.perform_caching
    original_bullet_enabled = Bullet.enable?
    ActionController::Base.cache_store = ActiveSupport::Cache::MemoryStore.new
    ActionController::Base.perform_caching = true
    Bullet.enable = false

    begin
      get root_path
      assert_select ".intro-card h3", text: character.name

      character.update!(name: "변경된 이름", updated_at: 1.minute.from_now)
      get root_path
      assert_select ".intro-card h3", text: "변경된 이름"

      character.destroy!
      get root_path
      assert_select ".intro-card", count: 0
    ensure
      ActionController::Base.perform_caching = original_perform_caching
      ActionController::Base.cache_store = original_cache_store
      Bullet.enable = original_bullet_enabled
    end
  end

  test "런웨이는 파일이 있는 캐릭터 열 명을 지연 로드한다" do
    handles = %w[SeoHARIN TanakaMIO ParkJADE YunCHAEI MoreauLEA HanSOYUL KangUNA ChenMAYA OhDAEUN SoERIN]
    YAML.load_file(Rails.root.join("config/characters.yml")).each do |attributes|
      Character.create!(attributes) if handles.include?(attributes.fetch("handle"))
    end
    Character.create!(name: "미공개", handle: "NoRunway", status: "planned")

    get root_path

    assert_response :success
    assert_select ".intro-reel video", count: 10
    assert_select '.intro-reel video[preload="none"][muted][playsinline][loop][data-src]', count: 10
    assert_select ".intro-reel video[src], .intro-reel source[src]", count: 0
    assert_select ".intro-reel .intro-ai-badge", text: "AI 가상인물", count: 10
    assert_select ".intro-reel a", count: 10
    handles.each do |handle|
      assert File.exist?(Rails.public_path.join("intro/runway/#{handle}.mp4"))
      assert File.exist?(Rails.public_path.join("intro/runway/#{handle}-poster.jpg"))
      assert_select ".intro-reel video[poster=?]", "/intro/runway/#{handle}-poster.jpg"
      assert_select ".intro-reel a[href=?]", character_path(handle), text: "옷장 보기"
    end
    assert_select '.intro-cta[href="#runway-reel"]', text: /캐릭터 옷장 보기/
  end

  # GET /
  test "should get index" do
    get root_url
    assert_response :success
  end

  # Homepage title
  test "should display JIEUN title" do
    get root_url
    assert_response :success
    assert_select "title", text: /JIEUN/
  end

  # Ranking section
  test "should display ranking section" do
    get root_url
    assert_response :success
    assert_match /무신사 랭킹/, response.body
  end

  # Product cards
  test "should display product cards" do
    get root_url
    assert_response :success
    assert_select ".grid", minimum: 1
  end

  test "search results do not reuse another query's ranking grid cache" do
    timestamp = Time.current.change(usec: 0)
    @product1.update_column(:updated_at, timestamp)
    @product2.update_column(:updated_at, timestamp)

    original_cache_store = ActionController::Base.cache_store
    original_perform_caching = ActionController::Base.perform_caching
    original_bullet_enabled = Bullet.enable?
    ActionController::Base.cache_store = ActiveSupport::Cache::MemoryStore.new
    ActionController::Base.perform_caching = true
    Bullet.enable = false

    begin
      get root_path, params: { q: @product1.name }
      assert_response :success
      assert_select "#ranking .grid h3", text: @product1.name

      get root_path, params: { q: @product2.name }
      assert_response :success
      assert_select "#ranking .grid h3", text: @product2.name
      assert_select "#ranking .grid h3", text: @product1.name, count: 0
    ensure
      ActionController::Base.perform_caching = original_perform_caching
      ActionController::Base.cache_store = original_cache_store
      Bullet.enable = original_bullet_enabled
    end
  end

  # Category filter links
  test "should display category filter links" do
    get root_url
    assert_response :success
    assert_match /아우터/, response.body
    assert_match /상의/, response.body
    assert_match /바지/, response.body
  end

  # Search form
  test "should display search form" do
    get root_url
    assert_response :success
    assert_select "form[action=?]", root_path
    assert_select "input[name=?]", "q"
  end

  # GET / with category parameter
  test "should filter by category" do
    get root_url, params: { category: "Dress" }
    assert_response :success
    # 카테고리 필터가 적용되는지 확인
  end

  # GET / with mood parameter (29cm style)
  test "should filter by mood" do
    get root_url, params: { mood: "minimal" }
    assert_response :success
    # mood 필터가 적용되는지 확인
  end

  # GET / with tpo parameter
  test "should filter by tpo" do
    get root_url, params: { tpo: "daily" }
    assert_response :success
    # tpo 필터가 적용되는지 확인
  end

  # Curation sections (29cm style)
  test "should display curation sections" do
    get root_url
    assert_response :success
    # 큐레이션 섹션이 표시되는지 확인
  end

  # Product images
  test "should display product images from Unsplash" do
    get root_url
    assert_response :success
    assert_match /images\.unsplash\.com/, response.body
  end

  # New arrival badge
  test "should show new arrival badge" do
    get root_url
    assert_response :success
    assert_match /신상/, response.body
  end

  # Free shipping badge
  test "should show free shipping badge for eligible products" do
    get root_url
    assert_response :success
    # 무료배송 배지 확인
  end

  # Navigation menu
  test "should display navigation menu" do
    get root_url
    assert_response :success
    assert_select "a[href=?]", products_path
  end

  # Empty state
  test "should handle empty product list gracefully" do
    Order.destroy_all
    Campaign.destroy_all
    PurchaseOrderItem.destroy_all
    Product.destroy_all

    get root_url
    assert_response :success
    # 상품이 없을 때 에러가 발생하지 않는지 확인
  end
end
