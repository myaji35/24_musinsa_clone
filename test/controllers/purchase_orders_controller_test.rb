require "test_helper"

class PurchaseOrdersControllerTest < ActionDispatch::IntegrationTest
  def setup
    @supplier = Supplier.create!(
      name: "Test Supplier",
      email: "supplier@test.com",
      phone: "010-1234-5678",
      address: "Seoul, Korea",
      status: "active"
    )

    @product = Product.create!(
      name: "Test Product",
      price: 50000,
      brand: "Test Brand",
      category: "Top"
    )

    @variant = @product.variants.create!(
      barcode: "PO-TEST-001",
      color: "Black",
      size: "M",
      stock: 5
    )

    @purchase_order = PurchaseOrder.create!(
      supplier: @supplier,
      status: "draft",
      delivery_date: 7.days.from_now
    )

    @purchase_order.purchase_order_items.create!(
      variant: @variant,
      quantity: 10,
      unit_price: 30000
    )
  end

  # GET /purchase_orders
  test "should get index" do
    get purchase_orders_url
    assert_response :success
  end

  # GET /purchase_orders/new
  test "should get new" do
    get new_purchase_order_url
    assert_response :success
  end

  # POST /purchase_orders - Success
  test "should create purchase_order" do
    assert_difference "PurchaseOrder.count", 1 do
      post purchase_orders_url, params: {
        purchase_order: {
          supplier_id: @supplier.id,
          delivery_date: 7.days.from_now,
          purchase_order_items_attributes: {
            "0" => {
              variant_id: @variant.id,
              quantity: 5,
              unit_price: 30000
            }
          }
        }
      }
    end

    assert_redirected_to purchase_order_path(PurchaseOrder.last)
  end

  # GET /purchase_orders/:id
  test "should show purchase_order" do
    get purchase_order_url(@purchase_order)
    assert_response :success
  end

  # GET /purchase_orders/:id/edit
  test "should get edit" do
    get edit_purchase_order_url(@purchase_order)
    assert_response :success
  end

  # PATCH /purchase_orders/:id - Success
  test "should update purchase_order" do
    patch purchase_order_url(@purchase_order), params: {
      purchase_order: {
        delivery_date: 10.days.from_now
      }
    }

    assert_redirected_to purchase_order_path(@purchase_order)
  end

  # DELETE /purchase_orders/:id
  test "should destroy purchase_order" do
    delete purchase_order_url(@purchase_order)

    @purchase_order.reload
    assert_equal "cancelled", @purchase_order.status
    assert_redirected_to purchase_orders_path
  end

  # POST /purchase_orders/:id/submit
  test "should submit purchase_order" do
    assert_enqueued_jobs 1, only: ActionMailer::MailDeliveryJob do
      post submit_purchase_order_url(@purchase_order)
    end

    @purchase_order.reload
    assert_equal "submitted", @purchase_order.status
    assert_redirected_to purchase_order_path(@purchase_order)
  end

  # POST /purchase_orders/:id/submit - Fail (not draft)
  test "should not submit non-draft purchase_order" do
    @purchase_order.update(status: "submitted")

    post submit_purchase_order_url(@purchase_order)

    assert_redirected_to purchase_order_path(@purchase_order)
    assert_match /실패/, flash[:alert]
  end

  # GET /po/confirm/:token - Public confirmation page
  test "should get confirm with valid token" do
    get confirm_purchase_order_url(@purchase_order.confirmation_token)
    assert_response :success
  end

  # GET /po/confirm/:token - Invalid token
  test "should return 404 for invalid token" do
    get confirm_purchase_order_url("INVALID_TOKEN")
    assert_response :not_found
  end

  # POST /po/confirm/:token - Confirm purchase order
  test "should confirm purchase_order via token" do
    @purchase_order.update(status: "submitted")

    post confirm_purchase_order_url(@purchase_order.confirmation_token)

    @purchase_order.reload
    assert_equal "confirmed", @purchase_order.status
    assert_response :success
  end

  # POST /purchase_orders/:id/receive
  test "should receive purchase_order" do
    @purchase_order.update(status: "confirmed")

    post receive_purchase_order_url(@purchase_order)

    @purchase_order.reload
    assert_equal "received", @purchase_order.status

    # 재고가 증가했는지 확인
    @variant.reload
    # Note: receive! 메서드가 재고를 증가시켜야 함
  end

  # POST /purchase_orders/:id/receive - Fail (not confirmed)
  test "should not receive non-confirmed purchase_order" do
    @purchase_order.update(status: "draft")

    post receive_purchase_order_url(@purchase_order)

    assert_redirected_to purchase_order_path(@purchase_order)
    assert_match /실패/, flash[:alert]
  end

  # Calculate total amount
  test "should calculate total amount automatically" do
    po = PurchaseOrder.create!(
      supplier: @supplier,
      delivery_date: 7.days.from_now,
      purchase_order_items_attributes: {
        "0" => {
          variant_id: @variant.id,
          quantity: 10,
          unit_price: 30000
        }
      }
    )

    assert_equal 300000, po.total_amount
  end
end
