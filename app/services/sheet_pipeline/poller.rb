module SheetPipeline
  class Poller
    REQUIRED_FIELDS = [ "상품코드", "상품명", "이미지" ].freeze

    def initialize(client:, sheet_name: ENV.fetch("JIEUN_SHEET_TAB", "입수"), steps: [], logger: Rails.logger)
      @client = client
      @sheet_name = sheet_name
      @steps = steps
      @logger = logger
    end

    def run_once
      rows = @client.read_rows(@sheet_name)
      layout = SheetLayout.new(sheet_name: @sheet_name, headers: rows.first || [])
      updates = []
      queued = 0
      failed = 0

      rows.drop(1).each_with_index do |values, index|
        row = { row_number: index + 2 }
        SheetLayout::HEADERS.each { |header| row[header] = values[layout.column_index(header) - 1] }
        next if REQUIRED_FIELDS.any? { |header| row[header].to_s.strip.empty? }
        next if row["상태"].to_s.start_with?("실패:")

        queued += 1
        changes = {}
        changes["상태"] = "대기" if row["상태"].to_s.strip.empty?

        @steps.each do |step|
          result = step.call(row)
          next unless result.is_a?(Hash)

          result.each do |header, value|
            layout.column_index(header)
            changes[header] = value
            row[header] = value
          end
        rescue StandardError => error
          failed += 1
          changes["상태"] = "실패:#{error.message.to_s[0, 80]}"
          @logger.error("시트 #{row[:row_number]}행 실패: #{error.class}: #{error.message}")
          break
        end

        changes.each do |header, value|
          updates << { range: layout.cell_ref(row[:row_number], header), values: [ [ value ] ] }
        end
      end

      @client.update_cells(updates) if updates.any?
      { read: rows.length - 1, queued: queued, failed: failed }
    end
  end
end
