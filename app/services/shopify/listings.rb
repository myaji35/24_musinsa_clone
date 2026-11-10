module Shopify
  class Listings
    def self.all
      YAML.safe_load_file(Rails.root.join("config/shopify/listings.yml"))
    end

    def self.for_variant(variant)
      all.select { |row| row["product_name"].present? && row["product_name"] == variant.product.name && row["color"] == variant.color }
    end

    def self.product(row)
      products = Product.where(name: row["product_name"]).limit(2).to_a
      products.one? ? products.first : nil
    end
  end
end
