require "test_helper"

class MagazineControllerTest < ActionDispatch::IntegrationTest
  test "다른 계정 사용자에게 초안 호와 매거진 메뉴가 노출되지 않는다" do
    post login_path, params: { email: users(:other).email, password: "TestPassword!2026" }
    assert_redirected_to workspace_path

    get magazine_path
    assert_response :success
    assert_select "[data-testid=magazine-issue]", count: 0
    assert_select "[data-testid=magazine-empty]", count: 1
    assert_select "nav a[href=?]", magazine_path, count: 0

    get magazine_article_path(1, "waist-first-silhouette")
    assert_response :not_found
  end

  test "초안 호는 손님에게 보이지 않고 기사 주소는 404" do
    get magazine_path
    assert_response :success
    assert_select "[data-testid=magazine-issue]", 0
    assert_select '[data-testid="magazine-empty"]', count: 1 do
      assert_select "p", text: "첫 호를 준비하고 있어요. 그동안 지금 판매 중인 상품을 둘러보세요."
      assert_select "a[href=?]", products_path, text: "상품 보러 가기", count: 1
      assert_select "a[href=?]", root_path, text: "랭킹 보기", count: 1
    end
    assert_select "p", text: "준비 중입니다.", count: 0

    get magazine_article_path(1, "waist-first-silhouette")
    assert_response :not_found
  end

  test "관리자는 초안 호와 기사를 미리보기한다" do
    sign_in

    get magazine_path
    assert_select "[data-testid=magazine-issue]", text: /초안 · 관리자 미리보기/

    get magazine_article_path(1, "waist-first-silhouette")
    assert_response :success
    assert_select "[data-testid=magazine-article] h1", text: "허리에서 시작되는 실루엣"
    assert_select "aside", text: /Styling Tip/
    assert_select "p", text: "기사 속 모델은 AI로 만든 가상 인물이며, 의류는 실제 판매 상품입니다."
  end

  test "매거진 원고의 상품·컷은 실제 카탈로그에 있다" do
    MagazineIssue.all.each do |issue|
      refs = [ issue.cover ] + issue.articles.flat_map { |article| [ article["hero"] ] + article["blocks"].select { |block| block["type"] == "image" } }
      refs.each do |ref|
        assert Rails.public_path.join("catalog", ref["product"], "#{ref['shot']}.jpg").exist?, "#{ref['product']}/#{ref['shot']} 없음"
      end
    end
  end
end
