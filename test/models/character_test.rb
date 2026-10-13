require "test_helper"

class CharacterTest < ActiveSupport::TestCase
  test "정본 동기화는 스무 명을 멱등으로 유지한다" do
    Rails.application.load_tasks
    2.times { Rake::Task["characters:sync"].reenable; Rake::Task["characters:sync"].invoke }
    assert_equal 20, Character.count
    assert_equal [ "KangUNA" ], Character.active.pluck(:handle)
  end
end
