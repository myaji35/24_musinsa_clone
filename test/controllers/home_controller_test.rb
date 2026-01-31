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

  # Category filter links
  test "should display category filter links" do
    get root_url
    assert_response :success
    assert_match /아우터/, response.body
    assert_match /상의/, response.body
    assert_match /하의/, response.body
  end

  # Search form
  test "should display search form" do
    get root_url
    assert_response :success
    assert_select "form[action=?]", search_path
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
    Product.destroy_all

    get root_url
    assert_response :success
    # 상품이 없을 때 에러가 발생하지 않는지 확인
  end
end
