require "test_helper"

class HomeIntroBudgetTest < ActionDispatch::IntegrationTest
  setup do
    YAML.load_file(Rails.root.join("config/characters.yml")).each do |attributes|
      Character.create!(attributes)
    end
  end

  test "홈은 히어로 하나만 자동 재생하고 런웨이 영상은 요청 전까지 지연한다" do
    get root_path

    assert_response :success
    assert_select "video[autoplay]", count: 1
    assert_select 'video[autoplay][src="/intro/yuna-runway.mp4"]', count: 1
    assert_select ".intro-reel video", count: 10
    assert_select '.intro-reel video[preload="none"][data-src]', count: 10
    assert_select ".intro-reel video[src], .intro-reel source", count: 0
    assert_select '.intro-reel button[type="button"][aria-label]', count: 10
    assert_select '.intro-reel button[disabled], .intro-reel button[tabindex="-1"]', count: 0
  end

  test "링 카드는 이름과 이미지 대체 텍스트를 제공하고 장식은 숨긴다" do
    get root_path

    assert_response :success
    assert_select ".intro-card img", count: 10
    css_select(".intro-card img").each do |image|
      assert image["alt"].present?
    end
    assert_select ".intro-card", count: 20
    css_select(".intro-card").each do |card|
      heading = card.at_css("h3")
      assert heading.text.present?
      assert_equal heading["id"], card["aria-labelledby"]
    end
    assert_select '.intro-card-initial[aria-hidden="true"]', count: 10
    assert_select '.intro-runway-perspective[aria-hidden="true"]', count: 1
    assert_select ".intro-cta[inert]", count: 1
  end
end
