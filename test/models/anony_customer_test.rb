require "test_helper"

class AnonyCustomerTest < ActiveSupport::TestCase
  test "UUID를 자동 생성하고 수정 시 보존한다" do
    customer = AnonyCustomer.create!
    assert_match /\A[0-9a-f-]{36}\z/, customer.uuid
    uuid = customer.uuid
    customer.update!(zip_prefix: "060")
    assert_equal uuid, customer.reload.uuid
  end

  test "UUID 중복과 식별자 길이를 검증한다" do
    customer = AnonyCustomer.new(uuid: anony_customers(:one).uuid, zip_prefix: "12", phone_suffix: "12345")
    assert_not customer.valid?
    %i[uuid zip_prefix phone_suffix].each { |attribute| assert customer.errors[attribute].present? }
  end

  test "취향을 Hash로 직렬화하고 누적 순으로 반환한다" do
    customer = AnonyCustomer.create!(preference_tags: { "minimal" => 2, "casual" => 1 })
    customer.add_preference("casual", 3)
    assert_equal({ "minimal" => 2, "casual" => 4 }, customer.reload.preference_tags)
    assert_equal({ "casual" => 4 }, customer.top_preferences(1))
  end

  test "동일 식별자로 조회하면 기존 고객을 반환한다" do
    customer = anony_customers(:one)
    assert_no_difference "AnonyCustomer.count" do
      assert_equal customer, AnonyCustomer.find_or_create_by_identifier(customer.phone_suffix, customer.birth_year)
    end
  end
end
