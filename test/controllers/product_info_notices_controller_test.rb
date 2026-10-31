require "test_helper"

class ProductInfoNoticesControllerTest < ActionDispatch::IntegrationTest
  test "비로그인 조회와 저장은 차단한다" do
    get product_info_notices_path
    assert_redirected_to login_path
    patch product_info_notices_path, params: { notices: { products(:one).id => { 소재: "면" } } }
    assert_redirected_to login_path
    assert_nil products(:one).reload.info_notice
  end

  test "미완성만 보여주고 전체 조회에서는 완성 상품도 공개 우선 이름순으로 보여준다" do
    sign_in
    complete = products(:one)
    incomplete = products(:two)
    complete.update!(info_notice: complete_notice, status: "draft")
    incomplete.update!(status: "published", info_notice: { "소재" => "TODO: 확인" })

    get product_info_notices_path
    assert_response :success
    assert_select "#product_notice_#{complete.id}", count: 0
    assert_select "#product_notice_#{incomplete.id} input", count: 9
    assert_select "p", text: "미완성 1개 / 전체 2개"

    get product_info_notices_path(all: 1)
    assert_select "tbody tr" do |rows|
      assert_equal [ incomplete.id, complete.id ], rows.map { |row| row["id"].delete_prefix("product_notice_").to_i }
    end
    assert_select "input[name='notices[#{complete.id}][소재]'][value='입력 소재']"
    incomplete.update!(status: "draft")
    complete.update!(name: "가 상품")
    incomplete.update!(name: "나 상품")
    get product_info_notices_path(all: 1)
    assert_select "tbody tr:first-child#product_notice_#{complete.id}"
  end

  test "일괄 저장은 허용 항목만 병합하고 상태를 유지하며 완료된 상품을 목록에서 제외한다" do
    sign_in
    complete = products(:one)
    partial = products(:two)
    complete.update!(status: "published", info_notice: { "기존키" => "유지" })
    partial.update!(status: "draft", info_notice: { "색상" => "검정" })
    patch product_info_notices_path, params: { notices: {
      complete.id => complete_notice.transform_values { |value| "  #{value}  " }.merge("status" => "draft", "임의키" => "무시"),
      partial.id => { "소재" => " 면 ", "status" => "published" },
      "999999999" => { "소재" => "없는 상품" }
    } }
    assert_redirected_to product_info_notices_path
    assert_equal "2개 상품의 상품정보를 저장했습니다. 남은 미완성 상품 1개", flash[:notice]
    assert_equal complete_notice.merge("기존키" => "유지"), complete.reload.info_notice
    assert_equal "published", complete.status
    assert_equal({ "색상" => "검정", "소재" => "면" }, partial.reload.info_notice)
    assert_equal "draft", partial.status
    follow_redirect!
    assert_select "#product_notice_#{complete.id}", count: 0
    assert_select "#product_notice_#{partial.id}", count: 1

    delete logout_path
    get product_path(complete)
    assert_response :success
    complete_notice.each_value { |value| assert_includes response.body, value }
    assert_select "[data-todo]", text: "확인 중", count: 0
    assert_not_includes response.body, "확인 중"
  end

  test "다른 항목이 옛 데이터라 검증에 걸리는 상품도 상품정보는 함께 저장된다" do
    sign_in
    products(:two).update_columns(brand: nil)
    patch product_info_notices_path, params: { notices: {
      products(:one).id => { "소재" => "면" }, products(:two).id => { "소재" => "울" }
    } }
    assert_redirected_to product_info_notices_path
    assert_equal "면", products(:one).reload.info_notice_value("소재")
    assert_equal "울", products(:two).reload.info_notice_value("소재")
    assert_nil products(:two).brand
  end

  private

  def complete_notice
    Product::INFO_NOTICE_FIELDS.index_with { |field| "입력 #{field}" }
  end
end
