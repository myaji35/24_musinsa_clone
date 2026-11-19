require "test_helper"

class SuppliersControllerTest < ActionDispatch::IntegrationTest
  def setup
    sign_in
    @supplier = Supplier.create!(account: accounts(:jieum),
      name: "Korea Fashion Wholesale",
      email: "supplier@kfashion.com",
      phone: "02-1234-5678",
      address: "Seoul, Dongdaemun",
      active: true
    )
  end

  # GET /suppliers
  test "should get index" do
    get suppliers_url
    assert_response :success
  end

  test "거래처 검색은 이름 담당자 연락처를 찾고 계정을 제한한다" do
    @supplier.update!(contact_person: "Alice", phone: "02-1234-5678")
    foreign = Supplier.create!(account: accounts(:other), name: "Korea Fashion Foreign", phone: "02-9999-9999", active: true)
    [ "  korea fashion  ", "alice", "1234" ].each do |query|
      get suppliers_path, params: { q: query }
      assert_select "a[href='#{supplier_path(@supplier)}']", minimum: 1
      assert_select "a[href='#{supplier_path(foreign)}']", count: 0
    end
    get suppliers_path, params: { q: "%" }
    assert_select "a[href='#{supplier_path(@supplier)}']", count: 0
    assert_select "div", text: "검색 결과가 없습니다."
  end

  test "모바일 카드에 빈 상세 줄을 표시하지 않는다" do
    @supplier.update!(contact_person: nil, payment_terms: nil, email: nil)
    get suppliers_path, params: { q: @supplier.name }
    assert_select "ul.md\\:hidden li" do
      assert_select "div.text-gray-600", count: 0
    end
    @supplier.update!(contact_person: "Alice")
    get suppliers_path, params: { q: @supplier.name }
    assert_select "ul.md\\:hidden li div.text-gray-600", text: "Alice"
  end

  # GET /suppliers/new
  test "should get new" do
    get new_supplier_url
    assert_response :success
  end

  # POST /suppliers - Success
  test "should create supplier" do
    assert_difference "Supplier.count", 1 do
      post suppliers_url, params: {
        supplier: {
          name: "New Supplier",
          email: "new@supplier.com",
          phone: "010-9999-8888",
          address: "Busan",
          active: true
        }
      }
    end

    assert_redirected_to suppliers_path
  end

  # POST /suppliers - Validation failure
  test "should not create supplier without name" do
    assert_no_difference "Supplier.count" do
      post suppliers_url, params: {
        supplier: {
          email: "invalid@supplier.com"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  # GET /suppliers/:id
  test "should show supplier" do
    get supplier_url(@supplier)
    assert_response :success
  end

  # GET /suppliers/:id/edit
  test "should get edit" do
    get edit_supplier_url(@supplier)
    assert_response :success
  end

  # PATCH /suppliers/:id - Success
  test "should update supplier" do
    patch supplier_url(@supplier), params: {
      supplier: {
        name: "Updated Supplier Name"
      }
    }

    assert_redirected_to supplier_path(@supplier)
    @supplier.reload
    assert_equal "Updated Supplier Name", @supplier.name
  end

  # DELETE /suppliers/:id
  test "should destroy supplier" do
    assert_no_difference "Supplier.count" do
      delete supplier_url(@supplier)
    end

    assert_not @supplier.reload.active?
    assert_redirected_to suppliers_path
  end

  # Supplier status filter
  test "should show only active suppliers" do
    inactive = Supplier.create!(account: accounts(:jieum),
      name: "Inactive Supplier",
      email: "inactive@supplier.com",
      phone: "010-0000-0000",
      address: "Seoul",
      active: false
    )

    get suppliers_url
    assert_response :success
    assert_select "a", text: @supplier.name
    assert_select "a", text: inactive.name, count: 0
  end

  # Supplier with purchase orders
  test "should show supplier with purchase orders" do
    PurchaseOrder.create!(
      supplier: @supplier,
      status: "draft",
      expected_delivery_date: 7.days.from_now
    )

    get supplier_url(@supplier)
    assert_response :success
    # 발주서 목록이 표시되는지 확인
  end
end
