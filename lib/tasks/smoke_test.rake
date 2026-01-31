# Smoke Test (연기 테스트) - 배포 후 기본 동작 확인
# Playwright 없이 curl + HTTParty로 운영 테스트

namespace :test do
  desc "Run smoke tests (curl-based) for production readiness"
  task smoke: :environment do
    require "net/http"
    require "json"

    BASE_URL = ENV["SMOKE_TEST_URL"] || "http://localhost:3000"

    puts "\n🔥 Running Smoke Tests..."
    puts "Target: #{BASE_URL}\n"

    tests_passed = 0
    tests_failed = 0

    # 테스트 헬퍼
    def test_url(name, path, expected_status: 200, contains: nil)
      url = URI("#{ENV["SMOKE_TEST_URL"] || "http://localhost:3000"}#{path}")
      response = Net::HTTP.get_response(url)

      if response.code.to_i == expected_status
        if contains && !response.body.include?(contains)
          puts "  ❌ #{name}: Missing expected content '#{contains}'"
          return false
        end
        puts "  ✅ #{name}: #{response.code}"
        return true
      else
        puts "  ❌ #{name}: Expected #{expected_status}, got #{response.code}"
        return false
      end
    rescue => e
      puts "  ❌ #{name}: #{e.message}"
      return false
    end

    puts "\n📋 Scenario 1: Core Pages"
    puts "-" * 50
    tests_passed += 1 if test_url("Homepage", "/", contains: "JIEUN")
    tests_passed += 1 if test_url("Products List", "/products", contains: "grid")
    tests_passed += 1 if test_url("Health Check", "/up", expected_status: 200)

    puts "\n📋 Scenario 2: API Endpoints"
    puts "-" * 50

    # UCP API 테스트
    begin
      url = URI("#{BASE_URL}/api/v1/ucp/products?limit=1")
      response = Net::HTTP.get_response(url)
      json = JSON.parse(response.body)

      if json["status"] == "success" && json["products"].is_a?(Array)
        puts "  ✅ UCP API: Valid JSON response"
        tests_passed += 1
      else
        puts "  ❌ UCP API: Invalid response structure"
        tests_failed += 1
      end
    rescue => e
      puts "  ❌ UCP API: #{e.message}"
      tests_failed += 1
    end

    puts "\n📋 Scenario 3: Search & Filter"
    puts "-" * 50
    tests_passed += 1 if test_url("Search", "/products?q=coat", contains: "grid")
    tests_passed += 1 if test_url("Category Filter", "/?category=아우터", contains: "grid")

    puts "\n📋 Scenario 4: Inventory Management"
    puts "-" * 50
    tests_passed += 1 if test_url("Inventory Scan", "/inventory/scan", expected_status: 200)
    tests_passed += 1 if test_url("Dashboard", "/dashboard/index", expected_status: 200)

    puts "\n📋 Scenario 5: Supplier & Purchase Orders"
    puts "-" * 50
    tests_passed += 1 if test_url("Suppliers", "/suppliers", expected_status: 200)
    tests_passed += 1 if test_url("Purchase Orders", "/purchase_orders", expected_status: 200)

    # 이미지 로드 테스트
    puts "\n📋 Scenario 6: Asset Loading"
    puts "-" * 50

    begin
      url = URI("https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?w=400&h=500&fit=crop")
      response = Net::HTTP.get_response(url)

      if response.code.to_i == 200
        puts "  ✅ Unsplash Images: Accessible"
        tests_passed += 1
      else
        puts "  ❌ Unsplash Images: #{response.code}"
        tests_failed += 1
      end
    rescue => e
      puts "  ⚠️  Unsplash Images: #{e.message} (external dependency)"
    end

    # 결과 요약
    puts "\n" + "=" * 50
    puts "📊 Test Results"
    puts "=" * 50
    puts "✅ Passed: #{tests_passed}"
    puts "❌ Failed: #{tests_failed}"
    puts "📈 Success Rate: #{(tests_passed.to_f / (tests_passed + tests_failed) * 100).round(2)}%"
    puts "=" * 50

    if tests_failed > 0
      puts "\n⚠️  Some tests failed. Check logs above."
      exit 1
    else
      puts "\n🎉 All smoke tests passed! Ready for deployment."
    end
  end

  desc "Run smoke tests with detailed output"
  task :smoke_verbose do
    ENV["SMOKE_TEST_VERBOSE"] = "true"
    Rake::Task["test:smoke"].invoke
  end

  desc "Run smoke tests for staging environment"
  task :smoke_staging do
    ENV["SMOKE_TEST_URL"] = "https://staging.jieun-fashion.com"
    Rake::Task["test:smoke"].invoke
  end

  desc "Run smoke tests for production environment"
  task :smoke_production do
    ENV["SMOKE_TEST_URL"] = "https://jieun-fashion.com"
    Rake::Task["test:smoke"].invoke
  end
end
