module Shopify
  class Pricing
    def self.overseas_usd(krw, rate: ENV.fetch("SHOPIFY_KRW_PER_USD", "1450"))
      amount = BigDecimal(krw.to_s)
      exchange = BigDecimal(rate.to_s)
      raise ArgumentError, "가격과 환율을 확인하세요" unless amount.finite? && amount >= 0 && exchange.finite? && exchange > 0

      [ ((amount * 2 / exchange - 9) / 10).round(0, :half_up).to_i * 10 + 9, 9 ].max
    end
  end
end
