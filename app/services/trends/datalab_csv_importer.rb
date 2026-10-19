require "csv"

module Trends
  class DatalabCsvImporter
    class Error < StandardError; end
    Result = Struct.new(:created, :updated, :skipped, keyword_init: true)

    def call(file, age_band: nil, note: nil)
      age_band = age_band.presence&.to_i
      raise Error, "연령대는 전체 또는 20/30/40/50을 선택하세요." unless age_band.nil? || [ 20, 30, 40, 50 ].include?(age_band)
      raw = file.respond_to?(:read) ? file.read : file.to_s
      text = raw.dup.force_encoding(Encoding::UTF_8)
      text = raw.dup.force_encoding("CP949").encode("UTF-8") unless text.valid_encoding?
      lines = text.delete_prefix("\uFEFF").lines
      header_index = lines.index { |line| line.match?(/\A\s*"?(날짜|기간|period)"?\s*[,;\t]/i) }
      raise Error, "날짜/기간/period로 시작하는 CSV 헤더를 찾을 수 없습니다." unless header_index
      rows = CSV.parse(lines.drop(header_index).join)
      headers = rows.shift.map { |value| value.to_s.strip }
      result = Result.new(created: 0, updated: 0, skipped: [])
      values = Hash.new { |hash, key| hash[key] = [] }
      rows.each_with_index do |row, index|
        next if row.all?(&:blank?)
        line_number = header_index + index + 2
        begin
          date = parse_date(row.first).beginning_of_week(:monday)
        rescue ArgumentError
          result.skipped << "#{line_number}행: 날짜 형식이 올바르지 않습니다."
          next
        end
        headers.drop(1).each_with_index do |name, column|
          begin
            ratio = BigDecimal(row[column + 1].to_s.strip)
            raise ArgumentError unless ratio.finite? && ratio.between?(0, 100) && name.present?
            values[[ name, date ]] << ratio
          rescue ArgumentError
            result.skipped << "#{line_number}행 #{name.presence || '빈 시리즈'}: 지수는 0~100 숫자여야 합니다."
          end
        end
      end
      TrendSnapshot.transaction do
        values.each do |(name, week), ratios|
          created = TrendSnapshot.store!(source: "datalab_csv", series_name: name, period_start: week,
            ratio: ratios.sum / ratios.size, age_band: age_band, gender: nil, note: note, imported_at: Time.current)
          created ? result.created += 1 : result.updated += 1
        end
      end
      result
    rescue CSV::MalformedCSVError, EncodingError => e
      Rails.logger.warn("DatalabCsvImporter: #{e.class}: #{e.message}")
      raise Error, "CSV 파일을 읽을 수 없습니다. 데이터랩에서 내려받은 CSV(UTF-8 또는 엑셀 CSV)인지 확인하세요."
    end

    private

    def parse_date(value)
      value = value.to_s.strip
      format = case value
      when /\A\d{4}-\d{2}-\d{2}\z/ then "%Y-%m-%d"
      when /\A\d{4}\.\d{2}\.\d{2}\z/ then "%Y.%m.%d"
      when /\A\d{8}\z/ then "%Y%m%d"
      else raise ArgumentError
      end
      Date.strptime(value, format)
    end
  end
end
