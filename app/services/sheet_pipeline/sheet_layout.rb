module SheetPipeline
  class SheetLayout
    HEADERS = [ "상품코드", "상품명", "이미지", "소구포인트1", "소구포인트2", "소구포인트3", "가격·색상", "상태", "추천 모델", "결과 링크" ].freeze

    class MissingHeader < StandardError; end

    def initialize(sheet_name:, headers:)
      @sheet_name = sheet_name
      @positions = headers.each_with_index.to_h { |header, index| [ header, index + 1 ] }
      missing = HEADERS.reject { |header| @positions.key?(header) }
      raise MissingHeader, "누락된 헤더: #{missing.join(', ')}" if missing.any?
    end

    def column_index(header)
      @positions.fetch(header)
    end

    def cell_ref(row_number, header)
      "#{@sheet_name}!#{self.class.column_letter(column_index(header))}#{row_number}"
    end

    def self.column_letter(number)
      raise ArgumentError, "열 번호는 1 이상이어야 합니다" if number < 1

      letters = +""
      while number.positive?
        number, remainder = (number - 1).divmod(26)
        letters.prepend((65 + remainder).chr)
      end
      letters
    end
  end
end
