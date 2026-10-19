require "test_helper"

class HomeHelperTest < ActionView::TestCase
  test "moods resolve to their hosts with one character query" do
    hosts = {
      "minimal" => Character.create!(handle: "SeoHARIN", name: "서하린"),
      "casual" => Character.create!(handle: "TanakaMIO", name: "타나카 미오"),
      "delicate" => Character.create!(handle: "YunCHAEI", name: "윤채이")
    }

    assert_queries_count(1) do
      hosts.each do |mood, character|
        assert_equal character, mood_host(mood)
      end
      assert_equal hosts["minimal"], mood_host("minimal")
    end
  end

  test "missing hosts and unknown moods return nil" do
    Character.where(handle: HomeHelper::MOOD_HOSTS.values).delete_all

    assert_nil mood_host("minimal")
    assert_nil mood_host("casual")
    assert_nil mood_host("delicate")
    assert_nil mood_host("unknown")
  end
end
