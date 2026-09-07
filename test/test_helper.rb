ENV["RAILS_ENV"] ||= "test"

# SimpleCov configuration (must be loaded before Rails)
if ENV["COVERAGE"]
  require "simplecov"

  SimpleCov.start "rails" do
    add_filter "/test/"
    add_filter "/config/"
    add_filter "/vendor/"

    add_group "Models", "app/models"
    add_group "Controllers", "app/controllers"
    add_group "Helpers", "app/helpers"
    add_group "Jobs", "app/jobs"
    add_group "Services", "app/services"

    minimum_coverage 80
    minimum_coverage_by_file 70

    track_files "{app,lib}/**/*.rb"
  end

  puts "📊 SimpleCov enabled - Coverage report will be generated in coverage/"
end

require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

class ActionDispatch::IntegrationTest
  # 실제 로그인 요청으로 관리자 세션을 생성한다.
  def sign_in(user = users(:one), password: "TestPassword!2026")
    post login_path, params: { email: user.email, password: password }
    assert_redirected_to inventory_scan_path
  end
end
