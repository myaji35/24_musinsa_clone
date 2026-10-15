require "test_helper"

class SheetPipeline::GwsClientTest < ActiveSupport::TestCase
  Status = Struct.new(:success?)

  test "읽기 명령에 인자 배열과 JSON 매개변수를 전달한다" do
    commands = []
    runner = ->(*args) do
      commands << args
      [ '{"values":[["상품코드"],["A-1"]]}', "", Status.new(true) ]
    end

    rows = SheetPipeline::GwsClient.new(spreadsheet_id: "test-id", runner: runner).read_rows("입수")

    assert_equal [ [ "상품코드" ], [ "A-1" ] ], rows
    assert_equal [ ENV.fetch("GWS_BIN", "gws"), "sheets", "spreadsheets", "values", "get", "--params" ], commands.first.take(6)
    assert_equal({ "spreadsheetId" => "test-id", "range" => "입수" }, JSON.parse(commands.first.last))
  end

  test "일괄 쓰기 명령에 USER_ENTERED 데이터를 전달한다" do
    commands = []
    runner = ->(*args) do
      commands << args
      [ "{}", "", Status.new(true) ]
    end
    updates = [ { range: "입수!H5", values: [ [ "대기" ] ] } ]

    SheetPipeline::GwsClient.new(spreadsheet_id: "test-id", runner: runner).update_cells(updates)

    assert_equal [ ENV.fetch("GWS_BIN", "gws"), "sheets", "spreadsheets", "values", "batchUpdate", "--params" ], commands.first.take(6)
    assert_equal({ "spreadsheetId" => "test-id" }, JSON.parse(commands.first[6]))
    assert_equal "--json", commands.first[7]
    assert_equal({ "valueInputOption" => "USER_ENTERED", "data" => [ { "range" => "입수!H5", "values" => [ [ "대기" ] ] } ] }, JSON.parse(commands.first[8]))
  end

  test "비정상 종료의 stderr를 포함해 예외를 올린다" do
    runner = ->(*) { [ "", "권한 없음", Status.new(false) ] }
    client = SheetPipeline::GwsClient.new(spreadsheet_id: "test-id", runner: runner)

    error = assert_raises(SheetPipeline::GwsClient::Error) { client.read_rows("입수") }
    assert_includes error.message, "권한 없음"
  end

  test "시트 ID가 없으면 예외를 올린다" do
    error = assert_raises(ArgumentError) { SheetPipeline::GwsClient.new(spreadsheet_id: nil) }
    assert_equal "JIEUN_SHEET_ID 미설정", error.message
  end
end
