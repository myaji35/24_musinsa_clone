require "test_helper"

class ProductSpecsControllerTest < ActionDispatch::IntegrationTest
  test "비로그인과 다른 계정은 편집 저장 현황에 접근할 수 없다" do
    get edit_product_spec_path(products(:one))
    assert_redirected_to login_path
    patch product_spec_path(products(:one)), params: { product: { spec: { note: "메모" } } }
    assert_redirected_to login_path
    get product_specs_path
    assert_redirected_to login_path
    post login_path, params: { email: users(:other).email, password: "TestPassword!2026" }
    get edit_product_spec_path(products(:one))
    assert_redirected_to workspace_path
    get product_specs_path
    assert_redirected_to workspace_path
    patch product_spec_path(products(:one)), params: { product: { spec: { note: "메모" } } }
    assert_redirected_to workspace_path
    assert_nil products(:one).reload.spec
  end

  test "몰 관리자는 편집 저장하고 실패 시 한국어 오류와 입력을 유지한다" do
    sign_in
    product = products(:one)
    get edit_product_spec_path(product)
    assert_response :success
    patch product_spec_path(product), params: { product: { spec: { measurements: { M: { 총장: "52.5" }, 과거: { 총장: "50" } }, material: { 겉감: "면" }, fit: { 계절: %w[봄 여름] } } } }
    assert_redirected_to edit_product_spec_path(product)
    assert_equal "상세스펙을 저장했습니다.", flash[:notice]
    assert_equal "52.5", product.reload.spec.dig("measurements", "M", "총장")
    patch product_spec_path(product), params: { product: { spec: { measurements: { M: { 총장: "52cm" } } } } }
    assert_response :unprocessable_entity
    assert_includes response.body, "M 사이즈 총장은 0보다 크고 300 이하인 숫자(cm)로 입력해 주세요"
    assert_select "input[value='52cm']"
    assert_equal "52.5", product.reload.spec.dig("measurements", "M", "총장")
    patch product_spec_path(product), params: { product: { spec: { measurements: { M: { 총장: "60" } } } } }
    assert_equal "50", product.reload.spec.dig("measurements", "과거", "총장")
  end

  test "현황은 모든 상품을 완성도 낮은 순으로 보여준다" do
    sign_in
    products(:one).update!(spec: { "material" => { "겉감" => "면" } }, status: "draft")
    products(:two).update!(status: "published")
    get product_specs_path
    assert_response :success
    assert_select "tbody tr" do |rows|
      assert_equal [ products(:two).id, products(:one).id ], rows.map { |row| row["id"].delete_prefix("product_spec_").to_i }
    end
    assert_includes response.body, "완성 0 / 전체 2"
  end

  test "상세페이지 사이즈 표는 실측이 있으면 현재 옵션 스펙을 우선한다" do
    product = products(:one)
    product.update!(status: "published", supplier_product_code: "JIEUM-G01", spec: { "measurements" => { "M" => { "총장" => "52.5" } } })
    get product_path(product)
    assert_response :success
    assert_select "a[href='#detail-size']", text: "사이즈 안내"
    assert_select "section[aria-labelledby='detail-size']" do
      assert_select "td", text: "52.5"
      assert_select "th", text: "S", count: 0
      assert_select "th", text: "M", count: 1
    end
    product.update!(spec: {})
    get product_path(product)
    assert_select "section[aria-labelledby='detail-size'] th", text: "S", count: 1
  end

  test "옵션이 없는 상품은 실측 입력 대신 안내를 보여준다" do
    sign_in
    product = Product.create!(name: "옵션 없는 상품", category: "상의", brand: "브랜드", price: 1000)
    get edit_product_spec_path(product)
    assert_response :success
    assert_includes response.body, "먼저 옵션(색상·사이즈)을 등록해 주세요"
    assert_select "input[inputmode='decimal']", count: 0
    patch product_spec_path(product), params: { product: { spec: { fit: { 계절: [ "" ] } } } }
    assert_redirected_to edit_product_spec_path(product)
    assert_empty product.reload.product_spec.fit("계절")
  end

  test "손님 상세는 스펙을 표시하고 TODO와 과거 사이즈는 숨긴다" do
    product = products(:one)
    product.update!(status: "published", spec: { "measurements" => { "M" => { "총장" => "52.5" }, "과거" => { "총장" => "77" } }, "material" => { "겉감" => "관리자 입력 소재", "안감" => "TODO: 비밀" }, "note" => "TODO: 숨김" })
    get product_path(product)
    assert_response :success
    assert_select "#product-spec" do
      assert_select "td", text: "52.5"
      assert_select "dd", text: "관리자 입력 소재"
      assert_select "th", text: "과거", count: 0
    end
    assert_not_includes response.body, "TODO:"
    assert_select "a[href='#product-spec']", text: "사이즈 안내"
    product.update!(spec: { "measurements" => { "M" => { "총장" => "TODO: 확인" } } })
    get product_path(product)
    assert_select "#product-spec", text: /실측 정보 준비 중/
    product.update!(status: "draft")
    get product_path(product)
    assert_response :not_found
  end
end
