require "test_helper"

class KakaoAgentTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:other)
    @device, @token = KakaoDevice.issue!(account: @account, name: "맥")
    @headers = { "Authorization" => "Bearer #{@token}" }
    @room = @account.kakao_rooms.create!(name: "거래처")
    @message = { author: "홍길동", body: "내용", date: "2026-11-06", time_raw: "오후 3:47" }
  end

  test "authentication config ordering and limit" do
    get "/api/kakao_agent/config"
    assert_response :unauthorized
    @room.update!(last_collected_at: Time.current)
    older = @account.kakao_rooms.create!(name: "오래된 방")
    @account.kakao_rooms.create!(name: "비활성", active: false)
    @device.update!(max_rooms_per_run: 1)
    get "/api/kakao_agent/config", headers: @headers
    assert_equal [ older.name ], response.parsed_body["rooms"]
    assert @device.reload.last_seen_at
    @device.update!(revoked_at: Time.current)
    get "/api/kakao_agent/config", headers: @headers
    assert_response :unauthorized
  end

  test "message deduplication validation and account isolation" do
    2.times do |index|
      post "/api/kakao_agent/messages", headers: @headers, as: :json, params: { room: @room.name, messages: [ @message, @message ] }
      assert_response :success
      assert_equal(index.zero? ? 1 : 0, response.parsed_body["created"])
    end
    assert_equal 1, @account.kakao_messages.count
    assert @device.reload.last_collected_at
    other_room = accounts(:jieum).kakao_rooms.create!(name: "남의 방")
    post "/api/kakao_agent/messages", headers: @headers, as: :json, params: { room: other_room.name, messages: [ @message ] }
    assert_response :unprocessable_entity
    assert_equal 0, other_room.kakao_messages.count
    [ [ @message.merge(body: "a" * 5001) ], Array.new(201, @message) ].each do |messages|
      post "/api/kakao_agent/messages", headers: @headers, as: :json, params: { room: @room.name, messages: messages }
      assert_response :unprocessable_entity
    end
    @room.update!(active: false)
    post "/api/kakao_agent/messages", headers: @headers, as: :json, params: { room: @room.name, messages: [] }
    assert_response :unprocessable_entity
  end

  test "status failure then recovery" do
    post "/api/kakao_agent/status", headers: @headers, as: :json, params: { ok: false, error: "실패" }
    assert_equal "실패", @device.reload.last_error
    assert @device.last_error_at
    post "/api/kakao_agent/status", headers: @headers, as: :json, params: { ok: true }
    assert_nil @device.reload.last_error
  end

  test "status accepts string true from form params" do
    @device.update!(last_error: "실패", last_error_at: Time.current)

    post "/api/kakao_agent/status", headers: @headers, params: { ok: "true", error: "실패" }

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
    token = response.body[/--token ([A-Za-z0-9_-]+)/, 1]
    assert token
    get workspace_kakao_path
    assert_response :success
    assert_not_includes response.body, token
    foreign, = KakaoDevice.issue!(account: accounts(:jieum), name: "남의 맥")
    foreign_room = accounts(:jieum).kakao_rooms.create!(name: "남의 방")
    patch workspace_kakao_device_path(foreign), params: { device: { max_rooms_per_run: 10 } }
    assert_response :not_found
    delete workspace_kakao_room_path(foreign_room)
    assert_response :not_found
  end
end
