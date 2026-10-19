require "test_helper"

class HomeCurationTest < ActionDispatch::IntegrationTest
  setup do
    assert_kind_of ActiveSupport::Cache::NullStore, Rails.cache
    products(:one).update!(ai_attributes: { mood: [ "minimal" ] })
  end

  test "curation links to its virtual host and the product catalog" do
    host = Character.create!(handle: "SeoHARIN", name: "서하린",
      wardrobe: "셔츠·슬랙스·코트", personality: "차분한 스타일을 선호합니다")

    get root_path

    assert_response :success
    assert_select "a[href=?]", character_path(host.handle) do
      assert_select "span", text: host.name
      assert_select "span", text: "가상 인물"
      assert_select "p", text: "서하린 스타일 — 셔츠·슬랙스·코트"
      assert_select "p", text: host.personality
      assert_select "img[alt=?][loading=lazy]", "서하린 (AI 가상 인물)"
    end
    assert_select "a[href=?]", products_path, text: "더 많은 상품 보기"
    assert_select 'a[href="#"]', text: "더 많은 상품 보기", count: 0
  end

  test "curation still renders without its host" do
    Character.where(handle: HomeHelper::MOOD_HOSTS.values).delete_all

    get root_path

    assert_response :success
    assert_select "h2", text: /미니멀/
    assert_select "a[href=?]", character_path("SeoHARIN"), count: 0
    assert_select "a[href=?]", products_path, text: "더 많은 상품 보기"
  end
end
