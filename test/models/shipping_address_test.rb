require "test_helper"

class ShippingAddressTest < ActiveSupport::TestCase
  test "필수값과 국내 우편번호 및 전화번호 형식을 검증한다" do
    address = shipping_addresses(:one)
    assert address.valid?
    assert_equal "061", address.zip_prefix
    %i[recipient_name phone postal_code address1 country_code].each do |field|
      copy = address.dup
      copy[field] = nil
      assert_not copy.valid?, field.to_s
    end
    address.assign_attributes(postal_code: "1234", phone: "010-abc-1234")
    assert_not address.valid?
    assert address.errors[:postal_code].any?
    assert address.errors[:phone].any?
    address.assign_attributes(country_code: "US", postal_code: "90210-1234", phone: "123456789")
    assert address.valid?
  end

  test "설정된 보관 기간을 사용하고 동의 배송지는 보존한다" do
    original = Rails.configuration.x.shipping_address_retention_days
    Rails.configuration.x.shipping_address_retention_days = 12
    address = shipping_addresses(:one)
    freeze_time do
      address.schedule_purge!
      assert_equal 12.days.from_now, address.reload.purge_after
      address.update!(save_consent: true, purge_after: nil)
      address.schedule_purge!
      assert_nil address.reload.purge_after
    end
  ensure
    Rails.configuration.x.shipping_address_retention_days = original
  end

  test "동의 철회 시 즉시 파기 대상이 된다" do
    address = shipping_addresses(:one)
    address.update!(save_consent: true, consented_at: Time.current)
    freeze_time do
      address.revoke_consent!
      assert_not address.reload.save_consent?
      assert_nil address.consented_at
      assert_equal Time.current, address.purge_after
      assert_includes ShippingAddress.purgeable, address
    end
  end
end
