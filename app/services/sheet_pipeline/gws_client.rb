require "json"
require "open3"

module SheetPipeline
  class GwsClient
    class Error < StandardError; end

    def initialize(spreadsheet_id: ENV["JIEUN_SHEET_ID"], runner: Open3.method(:capture3))
      raise ArgumentError, "JIEUN_SHEET_ID 미설정" if spreadsheet_id.nil? || spreadsheet_id.empty?

      @spreadsheet_id = spreadsheet_id
      @runner = runner
    end

    def read_rows(range)
      result = execute("get", "--params", JSON.generate(spreadsheetId: @spreadsheet_id, range: range))
      JSON.parse(result).fetch("values", [])
    end

    def update_cells(updates)
      execute(
        "batchUpdate",
        "--params", JSON.generate(spreadsheetId: @spreadsheet_id),
        "--json", JSON.generate(valueInputOption: "USER_ENTERED", data: updates)
      )
    end

    private

    def execute(action, *arguments)
      stdout, stderr, status = @runner.call(
        ENV.fetch("GWS_BIN", "gws"), "sheets", "spreadsheets", "values", action, *arguments
      )
      raise Error, "gws #{action} 실패: #{stderr}" unless status.success?

      stdout
    end
  end
end
