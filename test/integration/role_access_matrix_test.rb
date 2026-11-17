require "test_helper"

class RoleAccessMatrixTest < ActionDispatch::IntegrationTest
  STAFF = [ :operator, :admin ].freeze
  ADMIN = [ :admin ].freeze
  ROLES = { guest: nil, member: :member, operator: :operator, admin: :one }.freeze

  # 접근 표 4·5절: HTTP 메서드, fixture를 사용하는 경로, 허용 역할.
  ACCESS_MATRIX = [
    [ :get, -> { inventory_scan_path }, STAFF ],
    [ :get, -> { inventory_history_path }, STAFF ],
    [ :get, -> { admin_orders_path }, STAFF ],
    [ :get, -> { admin_order_claims_path }, STAFF ],
    [ :get, -> { dashboard_index_path }, STAFF ],
    [ :get, -> { purchase_orders_path }, STAFF ],
    [ :get, -> { new_purchase_order_path }, STAFF ],
    [ :delete, -> { purchase_order_path(purchase_orders(:one)) }, ADMIN ],
    [ :get, -> { supplier_claims_path }, STAFF ],
    [ :get, -> { supplier_imports_path }, STAFF ],
    [ :get, -> { suppliers_path }, STAFF ],
    [ :get, -> { supplier_path(suppliers(:one)) }, STAFF ],
    [ :get, -> { new_supplier_path }, ADMIN ],
    [ :post, -> { suppliers_path }, ADMIN ],
    [ :delete, -> { supplier_path(suppliers(:one)) }, ADMIN ],
    [ :get, -> { new_product_path }, STAFF ],
    [ :get, -> { edit_product_path(products(:one)) }, STAFF ],
    [ :delete, -> { product_path(deletable_product) }, ADMIN ],
    [ :get, -> { product_specs_path }, STAFF ],
    [ :get, -> { product_info_notices_path }, STAFF ],
    [ :get, -> { product_cutout_path(products(:one)) }, STAFF ],
    [ :get, -> { product_model_pick_path(products(:one)) }, STAFF ],
    [ :get, -> { admin_users_path }, ADMIN ],
    [ :get, -> { admin_access_logs_path }, ADMIN ],
    [ :patch, -> { admin_user_path(users(:member)) }, ADMIN ],
    [ :patch, -> { suspend_admin_user_path(users(:member)) }, ADMIN ],
    [ :get, -> { kpi_path }, ADMIN ],
    [ :get, -> { sales_path }, ADMIN ],
    [ :get, -> { trends_path }, ADMIN ],
    [ :get, -> { product_analyses_path }, ADMIN ],
    [ :post, -> { supplier_supplier_accounts_path(suppliers(:one)) }, ADMIN ],
    [ :post, -> { product_reviews_path(products(:one)) }, ADMIN ]
  ].freeze

  ACCESS_MATRIX.each_with_index do |(http_method, path_builder, allowed_roles), row|
    ROLES.each do |role, fixture|
      test "접근 표 #{row + 1}행 #{http_method} — #{role}" do
        login_as(fixture) if fixture
        path = instance_exec(&path_builder)
        public_send(http_method, path, params: request_params(http_method, path))

        if allowed_roles.include?(role)
          if http_method == :get
            assert_response :success
          else
            assert_operator response.status, :<, 400
            assert_not_includes [ login_url, root_url, inventory_scan_url ], response.location
          end
        else
          destination = { guest: login_url, member: root_url, operator: inventory_scan_url }.fetch(role)
          assert_redirected_to destination
        end
      end
    end
  end

  test "운영자는 비공개 상품을 볼 수 있다" do
    products(:one).update!(status: "draft")
    login_as(:operator)

    get product_path(products(:one))

    assert_response :success
  end

  test "일반 회원은 비공개 상품을 볼 수 없다" do
    products(:one).update!(status: "draft")
    login_as(:member)

    get product_path(products(:one))

    assert_response :not_found
  end

  test "손님도 발주 확인 토큰 주소를 열고 확인할 수 있다" do
    order = purchase_orders(:one)
    order.update!(status: "submitted")

    get confirm_purchase_order_path(order.confirmation_token)
    assert_response :success

    post confirm_purchase_order_path(order.confirmation_token)
    assert_response :success
    assert_equal "confirmed", order.reload.status
  end

  test "입점 업체 사용자는 거부 시 워크스페이스로 돌아간다" do
    post login_path, params: { email: users(:other).email, password: "TestPassword!2026" }
    assert_redirected_to workspace_path

    [ inventory_scan_path, kpi_path ].each do |path|
      get path
      assert_redirected_to workspace_path
      assert_equal "이 화면은 몰 관리자 전용입니다", flash[:alert]
    end
  end

  private

  # 원본 fixture에는 주문·발주가 연결되어 있으므로 삭제 요청만 독립된 복제본을 쓴다.
  def deletable_product
    @deletable_product ||= products(:one).dup.tap(&:save!)
  end

  def login_as(fixture)
    user = users(fixture)
    post login_path, params: { email: user.email, password: "TestPassword!2026" }
    assert_redirected_to(fixture == :member ? root_path : inventory_scan_path)
  end

  def request_params(http_method, path)
    return { user: { role: "operator" } } if http_method == :patch && path == admin_user_path(users(:member))
    return {} unless http_method == :post

    case path
    when suppliers_path
      { supplier: { name: "권한 표 거래처", phone: "02-1234-5678" } }
    when supplier_supplier_accounts_path(suppliers(:one))
      { supplier_account: { email: "matrix-partner@example.com", name: "권한 표 파트너", password: "TestPassword!2026" } }
    when product_reviews_path(products(:one))
      { review: { rating: 5, content: "권한 표 리뷰" } }
    else
      {}
    end
  end
end
