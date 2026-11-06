require "test_helper"

class KakaoAgentTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:other)
    @device, @token = KakaoDevice.issue!(account: @account, name: "맥")
    @headers = { "Authorization" => "Bearer #{@token}" }
    @room = @account.kakao_rooms.create!(name: "거래처")
    @message = { author: "홍길동", body: "내용", external_id: "notif:1", sent_at: "2026-11-06T15:47:20+09:00", time_precision: "second", truncated: false, is_mine: false }
  end

  test "authentication config ordering and limit" do
    get "/api/kakao_bridge/v1/config"
    assert_response :unauthorized
    @room.update!(last_collected_at: Time.current)
    older = @account.kakao_rooms.create!(name: "오래된 방", aliases: "별칭\n두번째")
    accounts(:jieum).kakao_rooms.create!(name: "남의 방")
    @account.kakao_rooms.create!(name: "비활성", active: false)
    get "/api/kakao_bridge/v1/config", headers: @headers
    assert_equal [ @room.id, older.id ], response.parsed_body["rooms"].map { |room| room["id"] }
    assert_equal 1, response.parsed_body["protocol"]
    assert_equal({ "enabled" => true, "poll_seconds" => 60 }, response.parsed_body["realtime"])
    assert_equal "03:00-05:00", response.parsed_body.dig("backfill", "window")
    assert_equal false, response.parsed_body.dig("open_window", "enabled")
    assert_equal [], response.parsed_body["rooms"].first["aliases"]
    assert_equal [ "별칭", "두번째" ], response.parsed_body["rooms"].last["aliases"]
    assert Time.iso8601(response.parsed_body["server_time"])
    assert @device.reload.last_seen_at
    @device.update!(revoked_at: Time.current)
    get "/api/kakao_bridge/v1/config", headers: @headers
    assert_response :unauthorized
  end

  test "message deduplication validation and account isolation" do
    2.times do |index|
      post "/api/kakao_bridge/v1/messages", headers: @headers, as: :json, params: { room: @room.name, source: "notification", messages: [ @message, @message ] }
      assert_response :success
      assert_equal(index.zero? ? 1 : 0, response.parsed_body["created"])
    end
    assert_equal 1, @account.kakao_messages.count
    assert @device.reload.last_collected_at
    other_room = accounts(:jieum).kakao_rooms.create!(name: "남의 방")
    post "/api/kakao_bridge/v1/messages", headers: @headers, as: :json, params: { room: other_room.name, messages: [ @message ] }
    assert_response :unprocessable_entity
    assert_equal 0, other_room.kakao_messages.count
    [ [ @message.merge(body: "a" * 5001) ], Array.new(201, @message) ].each do |messages|
      post "/api/kakao_bridge/v1/messages", headers: @headers, as: :json, params: { room: @room.name, source: "notification", messages: messages }
      assert_response :unprocessable_entity
    end
    @room.update!(active: false)
    post "/api/kakao_bridge/v1/messages", headers: @headers, as: :json, params: { room: @room.name, source: "notification", messages: [] }
    assert_response :unprocessable_entity
  end

  test "status failure then recovery" do
    post "/api/kakao_bridge/v1/status", headers: @headers, as: :json, params: { agent_version: "0.1.0", ok: false, permissions: { full_disk_access: true, accessibility: false }, last_realtime_at: "2026-11-06T15:47:20+09:00", last_backfill_at: "2026-11-06T03:00:00+09:00", error: "실패" }
    assert_equal "실패", @device.reload.last_error
    assert @device.last_error_at
    assert_equal "0.1.0", @device.agent_version
    assert_equal false, @device.ok
    assert_equal({ "full_disk_access" => true, "accessibility" => false }, @device.permissions)
    assert @device.last_realtime_at
    assert @device.last_backfill_at
    post "/api/kakao_bridge/v1/status", headers: @headers, as: :json, params: { ok: true }
    assert_nil @device.reload.last_error
  end

  test "status accepts string true from form params" do
    @device.update!(last_error: "실패", last_error_at: Time.current)

    post "/api/kakao_bridge/v1/status", headers: @headers, params: { ok: "true", error: "실패" }

    assert_response :success
    assert_nil @device.reload.last_error
    assert @device.last_seen_at
  end

  test "workspace membership token once and foreign resources" do
    get workspace_kakao_path
    assert_redirected_to login_path
    post login_path, params: { email: users(:other).email, password: "TestPassword!2026" }
    post workspace_kakao_devices_path, params: { name: "새 맥" }
    assert_response :success
    token = response.body[/font-mono">([A-Za-z0-9_-]+)</, 1]
    assert token
    get workspace_kakao_path
    assert_response :success
    assert_not_includes response.body, token
    assert_includes response.body, "전체 디스크 접근"
    assert_includes response.body, "kakao-bridge 에이전트 설치: install.sh, doctor 로 점검"
    patch workspace_kakao_device_path(@device), params: { device: { backfill_window: "25:00-05:00" } }
    assert_equal "03:00-05:00", @device.reload.backfill_window
    patch workspace_kakao_device_path(@device), params: { device: { backfill_window: "02:30-04:00", realtime_enabled: false } }
    assert_equal "02:30-04:00", @device.reload.backfill_window
    assert_equal false, @device.realtime_enabled
    patch workspace_kakao_room_path(@room), params: { aliases: "별칭1\n별칭2" }
    assert_equal [ "별칭1", "별칭2" ], @room.reload.alias_names
    foreign, = KakaoDevice.issue!(account: accounts(:jieum), name: "남의 맥")
    foreign_room = accounts(:jieum).kakao_rooms.create!(name: "남의 방")
    patch workspace_kakao_device_path(foreign), params: { device: { backfill_max_rooms: 10 } }
    assert_response :not_found
    delete workspace_kakao_room_path(foreign_room)
    assert_response :not_found
  end
end
