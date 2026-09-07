class NormalizeProductJsonAttributes < ActiveRecord::Migration[7.2]
  # 앱 모델의 콜백과 무관하게 기존 직렬화 데이터를 복구
  class MigrationProduct < ActiveRecord::Base
    self.table_name = "products"

    serialize :ai_attributes, coder: JSON
    serialize :badges, coder: JSON
  end

  def up
    MigrationProduct.find_each do |product|
      attributes = decode(product.ai_attributes)
      attributes = {} unless attributes.is_a?(Hash)
      %w[mood tpo].each do |key|
        attributes[key] = Array(attributes[key]).reject(&:blank?) if attributes.key?(key)
      end
      badges = decode(product.badges)
      badges = [] unless badges.is_a?(Array)

      product.update_columns(ai_attributes: attributes, badges: badges)
    end
  end

  def down
    # 잘못된 이중 직렬화 형식으로 되돌리지 않음
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def decode(value)
    value.is_a?(String) ? JSON.parse(value) : value
  rescue JSON::ParserError
    nil
  end
end
