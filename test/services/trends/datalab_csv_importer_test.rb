require "test_helper"
require "minitest/mock"

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
  test "CSV 구문과 인코딩 오류는 내부 내용을 로그에만 남긴다" do
    [ "날짜,코트\n\"닫히지 않은 값", "\xFF\xFE\x00\x81".b ].each do |content|
      logs = StringIO.new
      Rails.stub :logger, ActiveSupport::Logger.new(logs) do
        error = assert_raises(Trends::DatalabCsvImporter::Error) do
          Trends::DatalabCsvImporter.new.call(content)
        end
        assert_equal "CSV 파일을 읽을 수 없습니다. 데이터랩에서 내려받은 CSV(UTF-8 또는 엑셀 CSV)인지 확인하세요.", error.message
      end
      assert_match(/DatalabCsvImporter: (CSV::MalformedCSVError|Encoding::UndefinedConversionError|Encoding::InvalidByteSequenceError):/, logs.string)
    end
  end
end
