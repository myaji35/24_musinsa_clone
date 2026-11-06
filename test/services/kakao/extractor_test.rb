require "test_helper"

class KakaoExtractorTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  setup do
    @old_key = ENV["ANTHROPIC_API_KEY"]
    ENV["ANTHROPIC_API_KEY"] = "fake"
    @room = accounts(:jieum).kakao_rooms.create!(name: "분석 테스트", supplier: suppliers(:one))
    @message = @room.kakao_messages.create!(account: @room.account, body: "모레 20장 입금 10만원 010-1234-5678", sent_at: "2026-11-06T15:00:00+09:00")
  end

  teardown { ENV["ANTHROPIC_API_KEY"] = @old_key }

  def extract(items, refusal: false)
    response = Struct.new(:stop_reason, :content, :model).new(refusal ? "refusal" : "end_turn", [ Struct.new(:type, :text).new("text", { items: items }.to_json) ], "fake-model")
    test_case = self
    create = ->(**args) { test_case.instance_variable_set(:@request, args); response }
    messages = Object.new
    messages.define_singleton_method(:create, &create)
    api = Struct.new(:beta).new(Struct.new(:messages).new(messages))
    Kakao::Extractor.call(@room, client: api)
  end

  def item(ids = [ @message.id ])
    { kind: "delivery", summary: "20장 납품", date: "2026-11-08", quantity: 20, source_message_ids: ids }
  end

  test "payment promises default to schedules and completed payments require nonfuture dates" do
    travel_to Time.zone.local(2026, 11, 6, 12) do
      @room.supplier.update!(kind: "sales")
      @message.update!(body: "입금은 11/20에 1,560,000원 하겠습니다")
      assert extract([ item.merge(kind: "payment", progress: "planned", date: "2026-11-20", amount: 1560000) ]).success?
      extraction = @room.kakao_extractions.sole
      assert_equal "planned", extraction.progress
      assert_equal "schedule", extraction.default_target
      assert_no_difference "LedgerEntry.count" do
        assert_difference "ScheduleEvent.count", 1 do
          result = Kakao::Reviewer.call(extraction, user: users(:one), target: extraction.default_target)
          assert result.success?, result.error
        end
      end
      assert_equal Date.new(2026, 11, 20), extraction.reload.applied.starts_on
      extraction.assign_attributes(progress: "done", date: Date.current)
      assert_equal "receipt", extraction.default_target
      extraction.date = nil
      assert_equal "receipt", extraction.default_target
      extraction.date = Date.tomorrow
      assert_equal "schedule", extraction.default_target
      extraction.assign_attributes(progress: "unknown", date: Date.current)
      assert_equal "schedule", extraction.default_target
      extraction.assign_attributes(kind: "order", progress: "planned")
      assert_equal "schedule", extraction.default_target
      extraction.progress = "done"
      assert_equal "sale", extraction.default_target
      extraction.progress = "invalid"
      assert_not extraction.valid?
      assert_equal %w[planned done unknown], Kakao::Extractor::PROPERTIES["progress"][:enum]
    end
  end

  test "absolute date evidence privacy duplicates and gaps" do
    assert extract([ item, item([]), item([ -1 ]), item.merge(kind: "bad"), item.merge(date: "2026-99-99") ]).success?
    extraction = @room.kakao_extractions.sole
    assert_equal Date.new(2026, 11, 8), extraction.date
    assert_equal [ @message.id ], extraction.kakao_message_ids
    assert_not_includes @request[:messages].to_json, "010"
    assert_includes @request[:messages].to_json, "[가림]"
    assert_not @message.reload.extraction_gap?
    @message.reload.update!(needs_extraction: true)
    assert_no_difference "KakaoExtraction.count" do
      assert extract([ item ]).success?
    end
    @message.update!(body: "내일 30장")
    assert_equal "superseded", extraction.reload.status
    assert extract([]).success?
    assert @message.reload.extraction_gap?
  end

  test "approved evidence changes are flagged" do
    extract([ item ])
    extraction = @room.kakao_extractions.sole
    extraction.update!(status: "approved")
    @message.update!(body: "모레 30장")
    assert extraction.reload.source_changed?
    assert_equal "approved", extraction.status
  end

  test "missing key and refusal preserve pending messages" do
    ENV.delete("ANTHROPIC_API_KEY")
    assert Kakao::Extractor.call(@room).failure?
    assert_equal "ANTHROPIC_API_KEY 미설정", @room.reload.last_extraction_error
    ENV["ANTHROPIC_API_KEY"] = "fake"
    assert extract([], refusal: true).failure?
    assert @message.reload.needs_extraction?
  end

  test "approvals create schedule sale receipt and reject invalid ledger atomically" do
    %w[schedule sale receipt].each do |target|
      result = extract([ item ])
      assert result.success?, result.error
      extraction = @room.kakao_extractions.where(status: "pending").sole
      result = Kakao::Reviewer.call(extraction, user: users(:one), attributes: { amount: 1000, date: Date.current }, target: target)
      assert result.success?, result.error
      assert_equal target == "schedule" ? "ScheduleEvent" : "LedgerEntry", extraction.reload.applied_type
      assert_equal extraction, extraction.applied.source
      @message.reload.update!(needs_extraction: true)
    end
    extract([ item ])
    extraction = @room.kakao_extractions.where(status: "pending").sole
    assert_no_difference "LedgerEntry.count" do
      assert Kakao::Reviewer.call(extraction, user: users(:one), attributes: { supplier: nil, amount: nil }, target: "sale").failure?
    end
    assert_equal "pending", extraction.reload.status
    [ { amount: nil }, { amount: 1000, supplier: nil } ].each do |attributes|
      assert_no_difference "LedgerEntry.count" do
        result = Kakao::Reviewer.call(extraction, user: users(:one), attributes: attributes, target: "receipt")
        assert result.failure?
      end
      assert_equal "pending", extraction.reload.status
    end
  end
  test "context and target batch limits and client options" do
    @message.update!(needs_extraction: false)
    21.times do |index|
      @room.kakao_messages.create!(account: @room.account, body: "이전 맥락 #{index}", sent_at: @message.sent_at - (22 - index).minutes, needs_extraction: false)
    end
    101.times do |index|
      @room.kakao_messages.create!(account: @room.account, body: "대상 #{index}", sent_at: @message.sent_at + (index + 1).minutes)
    end
    assert extract([]).success?
    prompt = @request[:messages].first[:content]
    assert_equal 120, prompt.lines.count { |line| line.start_with?("[") }
    assert_includes prompt, "맥락(추출 대상 아님)"
    assert_not_includes prompt, "대상 100"
    assert_equal 1, @room.kakao_messages.where(needs_extraction: true).count
    assert_equal 16000, @request[:max_tokens]
    assert_equal :"claude-opus-5-5", @request[:model]
  end

  test "reservation deduplication and missing key job" do
    assert_enqueued_jobs 1, only: KakaoExtractJob do
      @room.schedule_extraction!
      @room.schedule_extraction!
    end
    assert @room.reload.extraction_scheduled_at.future?
    ENV.delete("ANTHROPIC_API_KEY")
    KakaoExtractJob.perform_now(@room.id)
    assert_equal "ANTHROPIC_API_KEY 미설정", @room.reload.last_extraction_error
    assert_nil @room.extraction_scheduled_at
    assert @message.reload.needs_extraction?
  end

  test "related records must belong to the same account" do
    foreign = accounts(:other).kakao_rooms.create!(name: "다른 계정")
    extraction = KakaoExtraction.new(account: @room.account, kind: "issue", summary: "확인", kakao_room: foreign)
    assert_not extraction.valid?
    @room.supplier = accounts(:other).suppliers.create!(name: "다른 거래처", phone: "010")
    assert_not @room.valid?
  end
end
