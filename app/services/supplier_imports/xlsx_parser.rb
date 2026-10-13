require "zip"
require "nokogiri"
require "pathname"

module SupplierImports
  class XlsxParser < ApplicationService
    HEADERS = {
      name: %w[상품명 제품명 품명], supplier_product_code: %w[상품코드 품번 코드],
      supply_price: %w[공급가 원가 도매가 공급단가], price: %w[판매가 소비자가 권장소비자가 권장가],
      category: %w[카테고리 분류 품목], brand: %w[브랜드], colors: %w[색상 컬러],
      sizes: %w[사이즈], material: %w[소재 혼용률], stock: %w[재고 수량],
      image_url: %w[이미지URL 이미지링크], description: %w[설명 상세]
    }.freeze
    NS = { "m" => "http://schemas.openxmlformats.org/spreadsheetml/2006/main",
           "r" => "http://schemas.openxmlformats.org/officeDocument/2006/relationships",
           "xdr" => "http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing",
           "a" => "http://schemas.openxmlformats.org/drawingml/2006/main" }.freeze

    def initialize(file)
      @file = file
    end

    def call
      bytes = @file.respond_to?(:download) ? @file.download : @file.read
      @zip = Zip::File.open_buffer(bytes)
      @sheet_path = first_sheet_path
      rows = parse_rows
      success(rows)
    rescue StandardError => e
      failure("엑셀 파싱 실패: #{e.message}")
    ensure
      @zip&.close
    end

    private

    def xml(path)
      entry = @zip.find_entry(path)
      entry && Nokogiri::XML(entry.get_input_stream.read)
    end

    def first_sheet_path
      workbook = xml("xl/workbook.xml")
      sheet = workbook.at_xpath("//m:sheets/m:sheet", NS)
      raise "첫 번째 시트를 찾을 수 없습니다" unless sheet

      target = relationships("xl/workbook.xml")[sheet["r:id"]]
      resolve("xl/workbook.xml", target)
    end

    def relationships(path)
      dir = File.dirname(path)
      rel_path = "#{dir}/_rels/#{File.basename(path)}.rels"
      doc = xml(rel_path)
      return {} unless doc

      doc.xpath("//*[local-name()='Relationship']").to_h { |rel| [ rel["Id"], rel["Target"] ] }
    end

    def resolve(base, target)
      raise "관계 파일 경로가 없습니다" if target.blank?

      clean = target.start_with?("/") ? target.delete_prefix("/") : Pathname.new(File.dirname(base)).join(target).cleanpath.to_s
      raise "잘못된 엑셀 경로" unless clean.start_with?("xl/")

      clean
    end

    def shared_strings
      doc = xml("xl/sharedStrings.xml")
      return [] unless doc

      doc.xpath("//m:si", NS).map { |node| node.xpath(".//m:t", NS).map(&:text).join }
    end

    def cell_value(cell, strings)
      case cell["t"]
      when "s" then strings[cell.at_xpath("./m:v", NS)&.text.to_i]
      when "inlineStr" then cell.xpath("./m:is//m:t", NS).map(&:text).join
      else cell.at_xpath("./m:v", NS)&.text
      end
    end

    def parse_rows
      sheet = xml(@sheet_path)
      raise "시트 데이터를 찾을 수 없습니다" unless sheet

      strings = shared_strings
      sheet_rows = sheet.xpath("//m:sheetData/m:row", NS)
      return [] if sheet_rows.empty?

      headers = sheet_rows.shift.xpath("./m:c", NS).to_h do |cell|
        value = cell_value(cell, strings).to_s.gsub(/\s+/, "")
        [ column_index(cell["r"]), HEADERS.find { |_, aliases| aliases.include?(value) }&.first ]
      end
      images = floating_images(sheet).merge(cell_images(sheet)) { |_row, first, _second| first }
      sheet_rows.map do |row|
        number = row["r"].to_i
        attrs = { row_number: number }
        row.xpath("./m:c", NS).each do |cell|
          key = headers[column_index(cell["r"])]
          attrs[key] = cell_value(cell, strings) if key
        end
        attrs[:image] = images[number]
        attrs
      end
    end

    def column_index(ref)
      ref.to_s[/\A[A-Z]+/].to_s.chars.reduce(0) { |number, char| number * 26 + char.ord - 64 }
    end

    def floating_images(sheet)
      sheet_rels = relationships(@sheet_path)
      images = {}
      sheet.xpath("//m:drawing", NS).each do |drawing|
        drawing_path = resolve(@sheet_path, sheet_rels[drawing["r:id"]])
        doc = xml(drawing_path)
        next unless doc

        rels = relationships(drawing_path)
        doc.xpath("//xdr:twoCellAnchor | //xdr:oneCellAnchor", NS).each do |anchor|
          row = anchor.at_xpath("./xdr:from/xdr:row", NS)&.text.to_i + 1
          embed = anchor.at_xpath(".//a:blip", NS)&.[]("r:embed")
          next if images[row] || !embed || !rels[embed]

          images[row] = image_data(resolve(drawing_path, rels[embed]))
        end
      end
      images
    end

    def cell_images(sheet)
      metadata = xml("xl/metadata.xml")
      rich = xml("xl/richData/rdrichvalue.xml")
      return {} unless metadata && rich

      rels = relationships("xl/richData/richValueRel.xml")
      rich_rels = xml("xl/richData/richValueRel.xml")
      return {} unless rich_rels

      image_ids = rich_rels.xpath("//*[local-name()='rel']").map { |node| node["r:id"] || node["id"] }
      values = rich.xpath("//*[local-name()='rv']")
      map = {}
      sheet.xpath("//m:c[@vm]", NS).each do |cell|
        vm = cell["vm"].to_i
        # vm은 metadata의 1 기반 valueMetadata 인덱스다.
        metadata_node = metadata.xpath("//*[local-name()='valueMetadata']/*[local-name()='bk']")[vm - 1]
        index = metadata_node&.at_xpath(".//*[local-name()='rc']")&.[]("v")&.to_i
        value = values[index] if index
        image_index = value&.at_xpath(".//*[local-name()='v']")&.text&.to_i
        relation = image_ids[image_index] if image_index
        path = rels[relation] if relation
        next unless path

        row = cell["r"][/\d+/].to_i
        map[row] ||= image_data(resolve("xl/richData/richValueRel.xml", path))
      end
      map
    end

    def image_data(path)
      entry = @zip.find_entry(path)
      return unless entry

      filename = File.basename(path)
      content_type = case File.extname(filename).downcase
      when ".png" then "image/png"
      when ".webp" then "image/webp"
      else "image/jpeg"
      end
      { filename: filename, content_type: content_type, io_bytes: entry.get_input_stream.read }
    end
  end
end
