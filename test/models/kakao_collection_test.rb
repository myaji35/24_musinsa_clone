require "test_helper"

class KakaoCollectionTest < ActiveSupport::TestCase
  setup do
    @device, @token = KakaoDevice.issue!(account: accounts(:other), name: "맥")
    @room = @device.account.kakao_rooms.create!(name: "거래처")
    @data = { author: "홍길동", body: "가" * 70, external_id: "notif:1", sent_at: "2026-11-06T15:47:20+09:00", time_precision: "second", truncated: true }
  end

  def ingest(data = @data, source = "notification", device = @device, room = @room)
    KakaoMessage.ingest!(device: device, room: room, source: source, messages: [ data ])
  end

  test "token is hashed authenticated and revoked" do
    assert_equal @device, KakaoDevice.authenticate(@token)
    assert_not_equal @token, @device.token_digest
    assert_nil KakaoDevice.authenticate("wrong")
    @device.update!(revoked_at: Time.current)
    assert_nil KakaoDevice.authenticate(@token)
  end

  test "truncated notification replaced with normalized full text and extraction reset" do
    ingest
    message = @room.kakao_messages.sole
    message.update!(needs_extraction: false)
    full = @data.merge(body: "가" * 100 + "  원문\n본문", external_id: "backfill:1", truncated: false, sent_at: "2026-11-06T15:47:00+09:00", time_precision: "minute")
    assert_equal 1, ingest(full, "backfill")[:merged]
    assert_equal 1, @room.kakao_messages.count
    message.reload
    assert_equal "가" * 100 + " 원문 본문", message.body
    assert_not message.truncated
    assert message.needs_extraction
    assert_equal 20, message.sent_at.sec
    assert_equal "notification,backfill", message.sources
    assert_equal 1, ingest(full, "backfill")[:duplicates]
    assert_equal 1, ingest[:duplicates]
  end

  test "same source preserves repeated messages three minutes apart" do
    assert_equal 1, ingest(@data, "backfill")[:created]
    repeated = @data.merge(external_id: "backfill:repeat", sent_at: "2026-11-06T15:50:20+09:00")
    assert_equal 1, ingest(repeated, "backfill")[:created]
    assert_equal 2, @room.kakao_messages.count
    assert_equal 1, ingest(repeated, "backfill")[:duplicates]
  end

  test "merge chooses nearest candidate without the incoming source" do
    ingest(@data, "backfill")
    nearer = @data.merge(external_id: "backfill:near", sent_at: "2026-11-06T15:50:20+09:00")
    ingest(nearer, "backfill")
    nearest = @room.kakao_messages.find_by!(external_id: nearer[:external_id])
    incoming = @data.merge(external_id: "notification:near", sent_at: "2026-11-06T15:50:00+09:00")
    assert_equal 1, ingest(incoming)[:merged]
    assert_equal "backfill,notification", nearest.reload.sources
    assert_equal 1, ingest(incoming.merge(external_id: "notification:again"))[:merged]
    assert_equal "backfill,notification", @room.kakao_messages.find_by!(external_id: @data[:external_id]).sources
    assert_equal 2, @room.kakao_messages.count
  end

  test "ingestion query count stays bounded with 500 existing account messages" do
    count_queries = lambda do |data|
      queries = []
      subscriber = lambda do |*args|
        payload = args.last
        queries << payload[:sql] unless payload[:name] == "SCHEMA" || payload[:sql].match?(/\A(?:BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE)/i)
      end
      ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") { ingest(data) }
      queries.size
    end
    baseline = count_queries.call(@data)
    now = Time.current
    KakaoMessage.insert_all!(500.times.map do |index|
      { account_id: @device.account_id, kakao_room_id: @room.id, body: "existing #{index}",
        match_key: KakaoMessage.key_for("existing #{index}"), sent_at: now, sources: "backfill",
        created_at: now, updated_at: now }
    end)
    queries = count_queries.call(@data.merge(external_id: "notification:bounded", body: "new message"))
    assert_operator queries, :<=, 10
    assert_operator queries, :<=, baseline
  end

  test "backfill time wins outside same minute and ten minute boundary is inclusive" do
    ingest
    full = @data.merge(external_id: "backfill:1", sent_at: "2026-11-06T15:37:20+09:00", time_precision: "minute")
    assert_equal 1, ingest(full, "backfill")[:merged]
    assert_equal Time.iso8601(full[:sent_at]), @room.kakao_messages.sole.sent_at
    assert_equal 1, ingest(@data.merge(external_id: "notif:2", sent_at: "2026-11-06T15:47:21+09:00"))[:created]
  end

  test "open window merges and reverse arrival preserves notification seconds" do
    original = @data.merge(external_id: "open:1", sent_at: "2026-11-06T15:47:00+09:00", time_precision: "minute", truncated: false)
    ingest(original, "open_window")
    assert_equal 1, ingest[:merged]
    assert_equal 20, @room.kakao_messages.sole.sent_at.sec
    assert_equal "open_window,notification", @room.kakao_messages.sole.sources
  end

  test "account room author and normalized prefix isolate matches" do
    ingest
    assert_equal 1, ingest(@data.merge(external_id: "notif:2", author: "다른 사람"))[:created]
    room = @device.account.kakao_rooms.create!(name: "다른 방")
    assert_equal 1, ingest(@data, "notification", @device, room)[:duplicates]
    assert_equal 1, ingest(@data.merge(external_id: "room:2"), "notification", @device, room)[:created]
    other, = KakaoDevice.issue!(account: accounts(:jieum), name: "다른 맥")
    other_room = other.account.kakao_rooms.create!(name: @room.name)
    assert_equal 1, ingest(@data, "notification", other, other_room)[:created]
    assert_equal KakaoMessage.key_for("가  나\n다"), KakaoMessage.key_for("가 나 다".unicode_normalize(:nfd))
    assert_raises(ActiveRecord::RecordInvalid) { other_room.kakao_messages.create!(account: @device.account, body: "내용") }
  end
end
