require "test_helper"

class SheetPipeline::SheetLayoutTest < ActiveSupport::TestCase
  test "헤더 순서가 바뀌어도 이름으로 셀을 찾는다" do
    headers = SheetPipeline::SheetLayout::HEADERS.reverse
    layout = SheetPipeline::SheetLayout.new(sheet_name: "입수", headers: headers)

    assert_equal "입수!C5", layout.cell_ref(5, "상태")
    assert_equal 3, layout.column_index("상태")
  end

  test "필수 헤더가 없으면 이름을 알린다" do
    headers = SheetPipeline::SheetLayout::HEADERS - [ "이미지", "상태" ]

    error = assert_raises(SheetPipeline::SheetLayout::MissingHeader) do
      SheetPipeline::SheetLayout.new(sheet_name: "입수", headers: headers)
    end
    assert_includes error.message, "이미지"
    assert_includes error.message, "상태"
  end

  test "26열과 27열을 A1 문자로 바꾼다" do
    assert_equal "Z", SheetPipeline::SheetLayout.column_letter(26)
    assert_equal "AA", SheetPipeline::SheetLayout.column_letter(27)
  end
end
