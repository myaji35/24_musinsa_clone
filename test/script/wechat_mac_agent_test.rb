require "test_helper"
require "minitest/mock"
require_relative "../../script/wechat_mac_agent/agent"

class WechatMacAgentTest < ActiveSupport::TestCase
  test "rate limiter enforces minimum spacing and rolling hourly cap" do
    limiter = WechatMacAgent::RateLimit.new
    assert limiter.allowed?(0)
    limiter.record(0)
    refute limiter.allowed?(19.99)
    assert limiter.allowed?(20)
    29.times { |index| limiter.record((index + 1) * 20) }
    refute limiter.allowed?(3599)
    assert limiter.allowed?(3600)
  end

  test "API sends bearer JSON and rejects failures and insecure remote URLs" do
    response = Struct.new(:code, :body).new("200", '[{"id":1}]')
    transport = lambda do |uri, request|
      assert_equal "/api/wechat_agent/outbox", uri.path
      assert_equal "Bearer secret", request["Authorization"]
      response
    end
    api = WechatMacAgent::Api.new(url: "https://example.com", token: "secret", transport: transport)
    assert_equal [ { "id" => 1 } ], api.call(:get, "outbox")
    response.code = "401"
    assert_raises(RuntimeError) { api.call(:get, "outbox") }
    assert_raises(RuntimeError) { WechatMacAgent::Api.new(url: "http://example.com", token: "secret") }
  end

  test "notification database is read only and restricted to WeChat app" do
    require "sqlite3"
    Dir.mktmpdir do |directory|
      path = File.join(directory, "db")
      db = SQLite3::Database.new(path)
      db.execute("CREATE TABLE app (app_id INTEGER, identifier TEXT)")
      db.execute("CREATE TABLE record (rec_id INTEGER, app_id INTEGER, data BLOB)")
      db.execute("INSERT INTO app VALUES (1, 'com.tencent.xinWeChat'), (2, 'other')")
      db.execute("INSERT INTO record VALUES (7, 1, 'plist'), (8, 2, 'other')")
      db.close
      ok = Struct.new(:success?).new(true)
      Open3.stub(:capture3, [ '{"req":{"titl":"工厂","body":"你好"}}', "", ok ]) do
        messages = WechatMacAgent::Notifications.new(path).poll
        assert_equal 1, messages.size
        assert_equal "notification:7", messages.first[:external_key]
        assert_equal "工厂", messages.first[:display_name]
        assert_equal "你好", messages.first[:content]
      end
      Open3.stub(:capture3, [ '{"req":{}}', "", ok ]) do
        assert_nil WechatMacAgent::Notifications.parse(9, "plist")
      end
    end
  end
end
