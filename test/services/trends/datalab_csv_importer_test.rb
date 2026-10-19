require "test_helper"

class Trends::DatalabCsvImporterTest < ActiveSupport::TestCase
  test "메타 와이드 CSV를 주간 평균으로 집계하고 재업로드시 갱신한다" do
    content = file_fixture("datalab_trends.csv").read
    importer = Trends::DatalabCsvImporter.new
    result = importer.call("\uFEFF#{content}", age_band: "20", note: "실측")
    assert_equal 4, result.created
    assert_equal 2, result.skipped.size
    snapshot = TrendSnapshot.find_by!(series_name: "코트", period_start: "2026-10-12")
    assert_equal 30, snapshot.ratio
    assert_equal 20, snapshot.age_band
    assert_equal "실측", snapshot.note
    assert_no_difference("TrendSnapshot.count") do
      result = importer.call(content, age_band: "20")
      assert_equal 4, result.updated
    end
  end

  test "전체 연령도 재업로드시 중복되지 않으며 CP949를 허용한다" do
    content = file_fixture("datalab_trends.csv").read.encode("CP949")
    importer = Trends::DatalabCsvImporter.new
    importer.call(content)
    assert_no_difference("TrendSnapshot.count") { importer.call(content) }
    assert_raises(ActiveRecord::RecordNotUnique) do
      snapshot = TrendSnapshot.first
      TrendSnapshot.insert_all!([ snapshot.attributes.except("id") ])
    end
  end

  test "헤더 없음은 한국어 오류" do
    error = assert_raises(Trends::DatalabCsvImporter::Error) { Trends::DatalabCsvImporter.new.call("메타 정보\n코트,10\n") }
    assert_match "헤더를 찾을 수 없습니다", error.message
  end
end
