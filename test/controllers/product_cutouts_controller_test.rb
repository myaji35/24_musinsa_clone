require "test_helper"

class ProductCutoutsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  def setup
    @product = products(:one)
    @product.image.attach(io: file_fixture("product.png").open, filename: "product.png", content_type: "image/png")
  end

  test "로그인하지 않으면 배경 제거를 시작할 수 없다" do
    post product_cutout_path(@product)

    assert_redirected_to login_path
    assert_equal 0, @product.image_processings.count
  end

  test "배경 제거를 누르면 처리 기록을 만들고 job 을 예약한다" do
    sign_in

    assert_enqueued_with(job: ProductImageProcessingJob) do
      post product_cutout_path(@product)
    end

    assert_redirected_to edit_product_path(@product, anchor: "cutout")
    assert_equal "pending", @product.image_processings.cutouts.last.status
  end

  test "처리 중이면 중복 요청을 만들지 않는다" do
    @product.image_processings.create!(kind: "cutout", status: "processing")
    sign_in

    assert_no_enqueued_jobs { post product_cutout_path(@product) }
    assert_equal 1, @product.image_processings.cutouts.count
  end

  test "원본 이미지가 없으면 시작하지 않는다" do
    @product.image.purge
    sign_in

    post product_cutout_path(@product)

    assert_equal "먼저 원본 이미지를 업로드해 주세요.", flash[:alert]
    assert_equal 0, @product.image_processings.count
  end

  test "편집 화면에 처리 중 상태와 폴링을 표시한다" do
    @product.image_processings.create!(kind: "cutout", status: "processing")
    sign_in

    get edit_product_path(@product)

    assert_response :success
    assert_select "turbo-frame#cutout_panel [data-testid=cutout-status]", text: "처리 중"
    assert_select "[data-controller=frame-poll][data-frame-poll-url-value=?]", product_cutout_path(@product)
    assert_select "turbo-frame#cutout_panel button[disabled]", text: "배경 제거"
  end

  test "실패하면 상태 배지와 사유를 표시하고 폴링하지 않는다" do
    @product.image_processings.create!(kind: "cutout", status: "failed", error_message: "rembg 서버에 연결할 수 없습니다")
    sign_in

    get product_cutout_path(@product)

    assert_response :success
    assert_select "[data-testid=cutout-status]", text: "실패"
    assert_select "p", text: /rembg 서버에 연결할 수 없습니다/
    assert_select "[data-controller=frame-poll]", count: 0
  end

  test "누끼를 대표 이미지로 채택하고 상세 화면에 반영한다" do
    @product.cutout_image.attach(io: file_fixture("product.png").open, filename: "cutout.png", content_type: "image/png")
    sign_in

    patch product_cutout_path(@product), params: { adopted: true }

    assert_redirected_to edit_product_path(@product, anchor: "cutout")
    assert @product.reload.cutout_adopted?
    get product_path(@product)
    assert_select "img[src*=?]", @product.cutout_image.blob.filename.to_s
  end

  test "누끼가 없으면 채택할 수 없다" do
    sign_in

    patch product_cutout_path(@product), params: { adopted: true }

    assert_equal "채택할 누끼 이미지가 없습니다.", flash[:alert]
    assert_not @product.reload.cutout_adopted?
  end

  test "원본으로 되돌린다" do
    @product.cutout_image.attach(io: file_fixture("product.png").open, filename: "cutout.png", content_type: "image/png")
    @product.update!(cutout_adopted: true)
    sign_in

    patch product_cutout_path(@product), params: { adopted: false }

    assert_not @product.reload.cutout_adopted?
  end
end
