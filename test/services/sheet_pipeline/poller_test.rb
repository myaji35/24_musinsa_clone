require "test_helper"
require "stringio"

class SheetPipeline::PollerTest < ActiveSupport::TestCase
  class FakeClient
    attr_reader :updates, :ranges

    def initialize(rows)
      @rows = rows
      @updates = []
      @ranges = []
    end

    def read_rows(range)
      @ranges << range
      @rows
    end

    def update_cells(cells)
      @updates << cells
    end
  end

  test "빈 상태를 대기로 쓰고 필수칸 빈 행을 무시하며 한 번만 쓴다" do
    client = FakeClient.new([ headers, row("A-1", "셔츠", "https://example.test/a"), row("A-2", "", "https://example.test/b"), row("A-3", "코트", "https://example.test/c") ])
    poller = SheetPipeline::Poller.new(client: client)

    assert_equal({ read: 3, queued: 2, failed: 0 }, poller.run_once)
    assert_equal [ "입수" ], client.ranges
    assert_equal 1, client.updates.length
    assert_equal [ "입수!H2", "입수!H4" ], client.updates.first.map { |update| update[:range] }
    assert client.updates.first.all? { |update| update[:values] == [ [ "대기" ] ] }
  end

  test "스텝 결과를 이어 전달하고 예외 행을 실패로 기록한 뒤 다음 행을 처리한다" do
    client = FakeClient.new([ headers, row("A-1", "셔츠", "url"), row("A-2", "코트", "url") ])
    seen = []
    first_step = ->(row) { { "추천 모델" => "모델 #{row['상품코드']}" } }
    second_step = ->(row) do
      seen << row["추천 모델"]
      raise "추천 불가" if row["상품코드"] == "A-1"

      { "결과 링크" => "https://example.test/result" }
    end
    log_output = StringIO.new
    logger = Logger.new(log_output)

    result = SheetPipeline::Poller.new(client: client, steps: [ first_step, second_step ], logger: logger).run_once

    assert_equal({ read: 2, queued: 2, failed: 1 }, result)
    assert_equal [ "모델 A-1", "모델 A-2" ], seen
    assert_equal 1, client.updates.length
    cells = client.updates.first.to_h { |update| [ update[:range], update[:values].first.first ] }
    assert_equal "실패:추천 불가", cells["입수!H2"]
    assert_equal "모델 A-2", cells["입수!I3"]
    assert_equal "https://example.test/result", cells["입수!J3"]
    assert_includes log_output.string, "추천 불가"
  end

  test "실패 상태 행은 건너뛴다" do
    failed_row = row("A-1", "셔츠", "url")
    failed_row[7] = "실패:이전 오류"
    client = FakeClient.new([ headers, failed_row ])

    assert_equal({ read: 1, queued: 0, failed: 0 }, SheetPipeline::Poller.new(client: client).run_once)
    assert_empty client.updates
  end

  test "halt는 시트에 쓰지 않고 변경 기록 후 남은 스텝을 건너뛴다" do
    client = FakeClient.new([ headers, row("A-1", "셔츠", "url") ])
    calls = 0
    first_step = ->(_row) { { "이미지판정" => "보완", "상태" => "MD확인 대기", :halt => true } }
    second_step = ->(_row) { calls += 1 }

    result = SheetPipeline::Poller.new(client: client, steps: [ first_step, second_step ]).run_once

    assert_equal({ read: 1, queued: 1, failed: 0 }, result)
    assert_equal 0, calls
    cells = client.updates.first.to_h { |update| [ update[:range], update[:values].first.first ] }
    assert_equal "MD확인 대기", cells["입수!H2"]
    assert_equal "보완", cells["입수!K2"]
  end

  test "헤더 누락은 호출자에게 올린다" do
    client = FakeClient.new([ headers - [ "상태" ] ])

    assert_raises(SheetPipeline::SheetLayout::MissingHeader) do
      SheetPipeline::Poller.new(client: client).run_once
    end
  end

  private

  def headers
    SheetPipeline::SheetLayout::HEADERS
  end

  def row(code, name, image)
    [ code, name, image ]
  end
end
