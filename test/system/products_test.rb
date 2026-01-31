require "application_system_test_case"

class ProductsTest < ApplicationSystemTestCase
  # 시나리오 6: 상품 목록 페이지
  test "상품 목록 페이지가 정상 작동하는가" do
    visit products_path

    # 상품 카드가 표시되는가
    assert_selector ".grid"

    # 이미지가 로드되는가 (Unsplash)
    assert_selector "img[src*='unsplash']", minimum: 1

    # 브랜드명이 표시되는가
    assert_selector ".font-bold", minimum: 1
  end

  # 시나리오 7: 상품 상세 페이지
  test "상품 상세 페이지가 정상 작동하는가" do
    product = products(:one)
    visit product_path(product)

    # 상품명이 표시되는가
    assert_text product.name

    # 가격이 표시되는가
    assert_text product.price.to_i.to_s
  end

  # 시나리오 8: 상품 카드 클릭
  test "상품 카드 클릭 시 상세 페이지로 이동하는가" do
    visit root_path

    # 첫 번째 상품 카드 클릭
    first("a.group.block.relative").click

    # 상세 페이지로 이동했는가
    assert_match /\/products\/\d+/, current_path
  end
end
