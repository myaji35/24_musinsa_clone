require "test_helper"

class ZeitwerkTest < ActiveSupport::TestCase
  test "eager loads all files" do
    assert_nothing_raised { Rails.application.eager_load! }
  end
end
