require "test_helper"

class SupplierImports::XlsxParserTest < ActiveSupport::TestCase
  test "첫 시트의 네 행과 그림을 파싱한다" do
    result = SupplierImports::XlsxParser.call(File.open(Rails.root.join("test/fixtures/files/supplier_sample.xlsx")))

    assert result.success?, result.error
    assert_equal 4, result.data.size
    assert_equal [ 2, 3, 4 ], result.data.filter_map { |row| row[:image] && row[:row_number] }
    assert_equal "셔츠", result.data.first[:name]
    assert_equal "SUP-001", result.data.first[:supplier_product_code]
    assert_equal "29000", result.data.first[:price]
    assert_nil result.data.last[:image]
  end

  test "헤더 동의어를 인식한다" do
    source = Zip::File.open_buffer(File.binread(Rails.root.join("test/fixtures/files/supplier_sample.xlsx")))
    output = Zip::OutputStream.write_buffer do |zip|
      source.each do |entry|
        content = entry.get_input_stream.read
        if entry.name == "xl/worksheets/sheet1.xml"
          document = Nokogiri::XML(content)
          { "A1" => "제품명", "D1" => "권장가", "I1" => "혼용률" }.each do |ref, label|
            document.at_xpath("//*[local-name()='c'][@r='#{ref}']/*[local-name()='is']/*[local-name()='t']").content = label
          end
          content = document.to_xml
        end
        zip.put_next_entry(entry.name)
        zip.write(content)
      end
    end
    source.close

    result = SupplierImports::XlsxParser.call(StringIO.new(output.string))
    assert result.success?, result.error
    assert_equal "셔츠", result.data.first[:name]
    assert_equal "29000", result.data.first[:price]
    assert_equal "면", result.data.first[:material]
  end

  test "셀 안 이미지 메타데이터도 행에 매핑한다" do
    source = Zip::File.open_buffer(File.binread(Rails.root.join("test/fixtures/files/supplier_sample.xlsx")))
    additions = {
      "xl/metadata.xml" => '<metadata><valueMetadata><bk><rc t="1" v="0"/></bk></valueMetadata></metadata>',
      "xl/richData/rdrichvalue.xml" => '<rvData><rv s="0"><v>0</v></rv></rvData>',
      "xl/richData/richValueRel.xml" => '<richValueRel xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><rel r:id="rId1"/></richValueRel>',
      "xl/richData/_rels/richValueRel.xml.rels" => '<Relationships><Relationship Id="rId1" Target="/xl/media/image1.jpeg"/></Relationships>'
    }
    output = Zip::OutputStream.write_buffer do |zip|
      source.each do |entry|
        next if entry.name.start_with?("xl/drawings/")

        content = entry.get_input_stream.read
        if entry.name == "xl/worksheets/sheet1.xml"
          document = Nokogiri::XML(content)
          document.at_xpath("//*[local-name()='c'][@r='C2']")["vm"] = "1"
          document.xpath("//*[local-name()='drawing']").remove
          content = document.to_xml
        end
        zip.put_next_entry(entry.name)
        zip.write(content)
      end
      additions.each do |path, content|
        zip.put_next_entry(path)
        zip.write(content)
      end
    end
    source.close

    result = SupplierImports::XlsxParser.call(StringIO.new(output.string))
    assert result.success?, result.error
    assert_equal 2, result.data.first[:row_number]
    assert_equal "image1.jpeg", result.data.first[:image][:filename]
  end
end
