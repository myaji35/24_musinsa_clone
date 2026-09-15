require "test_helper"

class SnapsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get snaps_url
    assert_response :success
    assert_select "a[href=?]", snap_path(snaps(:one))
    assert_select "div.aspect-\\[3\\/4\\]", count: Snap.count
    assert_select "span", text: "이미지 없음", count: Snap.count
    assert_select "img[src*='unsplash.com']", count: 0
    assert_select "a", text: "스냅 올리기", count: 0
    assert_no_match(/#데일리룩|#OOTD|#스트릿/, response.body)
  end

  test "should get show" do
    get snap_url(snaps(:one))
    assert_response :success
    assert_select "p", text: snaps(:one).user.name
    assert_select "p", text: snaps(:one).content
    assert_select "time[datetime=?]", snaps(:one).created_at.iso8601
    assert_select "a[href=?]", product_path(products(:one))
    assert_select "a[href=?]", product_path(products(:two)), count: 0
  end

  test "should omit product section when no products are linked" do
    SnapProduct.where(snap_id: snaps(:one).id).delete_all

    get snap_url(snaps(:one))

    assert_response :success
    assert_select "h2", text: "연결된 상품", count: 0
  end

  test "should not expose snap creation routes" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("/snaps", method: :post)
    end
    assert_not Rails.application.routes.url_helpers.respond_to?(:new_snap_path)
  end
end
