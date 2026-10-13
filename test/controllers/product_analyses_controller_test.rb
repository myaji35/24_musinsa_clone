require "test_helper"
require "minitest/mock"

class ProductAnalysesControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  def setup
    Bullet.enable = false
  end

  def teardown
    Bullet.enable = true
  end

  test "로그인이 필요하다" do
    get product_analyses_path
    assert_redirected_to login_path
    get kpi_path
    assert_redirected_to login_path
  end

  test "목록 상세 KPI를 보여준다" do
    sign_in
    analysis = products(:one).product_analyses.create!
    get product_analyses_path
    assert_response :success
    get product_analysis_path(analysis)
    assert_response :success
    get kpi_path
    assert_response :success
  end

  test "미분석 상품을 최대 50개 접수한다" do
    sign_in
    assert_enqueued_with(job: ProductAnalysisJob) do
      post analyze_pending_product_analyses_path
    end
    assert ProductAnalysis.exists?(product: products(:one))
  end

  test "분석 작업 등록 실패 시 분석을 실패로 저장하고 목록으로 이동한다" do
    sign_in
    error = SolidQueue::Job::EnqueueError.new("database is locked")
    ProductAnalysisJob.stub(:perform_later, ->(*) { raise error }) do
      post product_analyses_path, params: { product_id: products(:one).id }
    end

    analysis = products(:one).product_analyses.order(:id).last
    assert_redirected_to product_analyses_path
    assert_equal "failed", analysis.status
    assert_equal "작업 등록 실패(DB 잠김)", analysis.error_message
    assert_equal analysis.error_message, flash[:alert]
  end

  test "미분석 상품 작업 등록 실패 시 분석을 실패로 저장한다" do
    sign_in
    first_product = Product.order(:id).first
    error = ActiveRecord::StatementInvalid.new("database is locked")
    assert_difference("ProductAnalysis.count", 1) do
      ProductAnalysisJob.stub(:perform_later, ->(*) { raise error }) do
        post analyze_pending_product_analyses_path
      end
    end

    analysis = first_product.product_analyses.sole
    assert_redirected_to product_analyses_path
    assert_equal "failed", analysis.status
    assert_equal "작업 등록 실패(DB 잠김)", analysis.error_message
    assert_not ProductAnalysis.exists?(status: "pending")
  end

  test "목표 수량 수정은 목표 매출을 갱신한다" do
    sign_in
    analysis = products(:one).product_analyses.create!(status: "done")
    patch product_analysis_path(analysis), params: { product_analysis: { target_units_override: 4 } }
    assert_redirected_to product_analysis_path(analysis)
    assert_equal 79_600, analysis.reload.target_revenue
  end

  test "실패한 분석도 수동 배정하면 상세와 KPI에 반영한다" do
    sign_in
    character = Character.create!(name: "수동 캐릭터", handle: "manual_test")
    analysis = products(:one).product_analyses.create!(status: "failed", error_message: "API 키 없음")

    patch product_analysis_path(analysis), params: { product_analysis: {
      character_id: character.id, target_units_override: 10
    } }

    assert_redirected_to product_analysis_path(analysis)
    assert analysis.reload.manually_assigned?
    assert_equal 10, analysis.target_units
    assert_equal 199_000, analysis.target_revenue
    assert analysis.assumptions_json.present?

    get product_analysis_path(analysis)
    assert_select "span", text: "수동 배정"
    assert_select "p", text: /목표 매출: ₩199,000/
    assert_select ".border-red-300", text: /API 키 없음/
    assert_select "p", text: /컨셉:/, count: 0
    assert_select "p", text: /가정값 스냅샷:/, count: 0

    get product_analyses_path
    assert_select "span", text: "수동 배정"

    get kpi_path
    assert_select "tr", text: /수동 캐릭터.*1.*₩199,000/
    assert_select "tr", text: /미지정.*1.*₩199,000/
  end

  test "실패한 분석에 캐릭터만 배정하면 가정값 목표를 계산한다" do
    sign_in
    character = Character.create!(name: "수동 캐릭터", handle: "manual_only")
    analysis = products(:one).product_analyses.create!(status: "failed")

    patch product_analysis_path(analysis), params: { product_analysis: { character_id: character.id } }

    assert analysis.reload.manually_assigned?
    assert_equal 2, analysis.target_units
    assert_equal 39_800, analysis.target_revenue
    assert_equal 39_800, Kpi::Calculator.new.row(products(:one)).target_revenue
  end
end
