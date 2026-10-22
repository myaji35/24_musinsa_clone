require "test_helper"

class HomeStoryTest < ActionDispatch::IntegrationTest
  setup do
    assert_kind_of ActiveSupport::Cache::NullStore, Rails.cache
  end

  test "홈은 룩북 사진 다음에 그 묶음 상품 4개를 보여주고 카테고리 아이콘 판을 둔다" do
    coat = Product.create!(name: "숄칼라 벨티드 울 랩코트", price: 189000, brand: "JIEUM", category: "Outer", supplier_product_code: "JIEUM-G01")
    coat.variants.create!(color: "카멜", size: "M", stock: 3)

    get root_path

    assert_response :success
    assert_select "[data-testid=home-story]" do
      assert_select "h2", text: "울코트"
      assert_select "a[href=?]", product_path(coat)
      assert_select "img[srcset*=?]", "look1-1440.webp"
    end
    assert_select "#category-grid", text: "카테고리로 찾기"
    assert_select "a[href=?]", root_path(category: "패딩", anchor: "ranking")
  end

  test "카테고리를 고르면 스토리 없이 그 묶음만 보여준다" do
    padding = Product.create!(name: "후드 롱패딩", price: 229000, brand: "JIEUM", category: "Outer")
    coat = Product.create!(name: "울 롱코트", price: 199000, brand: "JIEUM", category: "Outer")

    get root_path(category: "패딩")

    assert_select "[data-testid=home-story]", 0
    assert_select "#ranking a[href=?]", product_path(padding)
    assert_select "#ranking a[href=?]", product_path(coat), 0
  end
end
