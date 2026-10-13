require "test_helper"
require "minitest/mock"

class SupplierImportsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  def setup
    Bullet.enable = false
  end

  def teardown
    Bullet.enable = true
  end

  test "로그인이 필요하다" do
    get supplier_imports_path
    assert_redirected_to login_path
  end

  test "업로드 후 잡이 실행되고 결과를 보여준다" do
    sign_in
    assert_difference "SupplierImport.count", 1 do
      perform_enqueued_jobs do
        post supplier_imports_path, params: { supplier_import: { supplier_id: suppliers(:one).id,
          file: fixture_file_upload("supplier_sample.xlsx", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet") } }
      end
    end
    item = SupplierImport.order(:id).last
    assert_redirected_to supplier_import_path(item)
    assert_equal "done", item.reload.status
    get supplier_import_path(item)
    assert_response :success
    assert_select "table tbody tr", count: 4
  end

  test "작업 등록 실패 시 가져오기를 실패로 저장하고 결과로 이동한다" do
    sign_in
    error = SolidQueue::Job::EnqueueError.new("database is locked")
    SupplierImportJob.stub(:perform_later, ->(*) { raise error }) do
      post supplier_imports_path, params: { supplier_import: { supplier_id: suppliers(:one).id,
        file: fixture_file_upload("supplier_sample.xlsx", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet") } }
    end

    item = SupplierImport.order(:id).last
    assert_redirected_to supplier_import_path(item)
    assert_equal "failed", item.status
    assert_equal "작업 등록 실패(DB 잠김) — 잠시 후 [다시 처리]를 눌러 주세요: SolidQueue::Job::EnqueueError", item.error_message
    assert_equal item.error_message, flash[:alert]
    get supplier_import_path(item)
    assert_select "form[action='#{retry_supplier_import_path(item)}'] svg"
  end

  test "실패한 가져오기를 다시 등록한다" do
    sign_in
    item = SupplierImport.create!(supplier: suppliers(:one), status: "failed", error_message: "이전 오류",
      file: fixture_file_upload("supplier_sample.xlsx", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"))
    enqueued_id = nil
    SupplierImportJob.stub(:perform_later, ->(id) { enqueued_id = id }) do
      post retry_supplier_import_path(item)
    end

    assert_redirected_to supplier_import_path(item)
    assert_equal item.id, enqueued_id
    assert_equal "pending", item.reload.status
    assert_nil item.error_message
  end
end
