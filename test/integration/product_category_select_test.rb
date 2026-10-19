require "test_helper"

class ProductCategorySelectTest < ActionDispatch::IntegrationTest
  setup do
    sign_in
    @product = Product.create!(name: "카테고리 보존 상품", brand: "테스트", price: 10000, category: "하의")
  end

  test "edit selects an existing category outside the list and preserves it on save" do
    get edit_product_path(@product)

    assert_response :success
    assert_select "select#product_category" do
      assert_select "option[value='하의']", count: 1, text: "하의 (기존 값)"
      assert_select "option[selected]", count: 1 do |options|
        assert_equal "하의", options.first["value"]
        patch product_path(@product), params: { product: { category: options.first["value"] } }
      end
    end

    assert_redirected_to product_path(@product)
    assert_equal "하의", @product.reload.category
  end

  test "edit does not duplicate a category already in the list" do
    @product.update!(category: "바지")

    get edit_product_path(@product)

    assert_response :success
    assert_select "select#product_category" do
      assert_select "option", count: 9
      assert_select "option[value='바지']", count: 1, text: "바지"
      assert_select "option[selected][value='바지']", count: 1
      assert_select "option", text: /기존 값/, count: 0
    end
  end

  test "new keeps the blank category prompt without existing values" do
    get new_product_path

    assert_response :success
    assert_select "select#product_category" do |selects|
      assert_select "option", count: 9
      assert_select "option[value='']", count: 1, text: "선택하세요"
      assert_select "option", text: /기존 값/, count: 0
      options = selects.first.css("option")
      selected = options.find { |option| option.key?("selected") } || options.first
      assert_equal "", selected["value"]
    end
  end
end
