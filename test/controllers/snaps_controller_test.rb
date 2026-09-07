require "test_helper"

class SnapsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get snaps_url
    assert_response :success
  end

  test "should get new" do
    sign_in
    get new_snap_url
    assert_response :success
  end

  test "should post create" do
    sign_in
    post snaps_url
    assert_response :success
  end

  test "should get show" do
    get snap_url(snaps(:one))
    assert_response :success
  end
end
