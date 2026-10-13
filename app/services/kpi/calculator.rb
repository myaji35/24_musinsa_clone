module Kpi
  class Calculator < ApplicationService
    Row = Struct.new(:product, :analysis, :target_units, :target_revenue, :actual_revenue,
      :achievement, :unit_margin, :video_cost, :breakeven_units, keyword_init: true)

    attr_reader :assumptions

    def initialize
      @assumptions = YAML.load_file(Rails.root.join("config/kpi_assumptions.yml")).stringify_keys
    end

    def target_units(override = nil)
      [ override || (assumptions.fetch("videos_per_product") * assumptions.fetch("views_per_video") *
        assumptions.fetch("click_through_rate") * assumptions.fetch("conversion_rate")).round, 0 ].max
    end

    def assign_target!(analysis)
      units = target_units(analysis.target_units_override)
      analysis.update!(target_units: units, target_revenue: units * analysis.product.price,
        assumptions_json: assumptions.to_json)
    end

    def achievement(actual, target)
      target.to_d.positive? ? (actual.to_d / target.to_d) : nil
    end

    def row(product, actual: nil)
      analysis = product.latest_analysis
      units = eligible_analysis?(analysis) ? analysis.effective_target_units : nil
      revenue = eligible_analysis?(analysis) ? analysis.target_revenue : nil
      actual ||= actual_for(product.id)
      margin = product.supply_price.nil? ? nil : product.price - product.supply_price
      cost = assumptions.fetch("videos_per_product") * assumptions.fetch("video_cost_krw_per_clip")
      Row.new(product: product, analysis: analysis, target_units: units, target_revenue: revenue,
        actual_revenue: actual, achievement: achievement(actual, revenue), unit_margin: margin,
        video_cost: cost, breakeven_units: margin&.positive? ? (cost.to_d / margin).ceil : nil)
    end

    def rows(products = Product.all)
      actuals = actuals_by_product
      products.includes(:latest_analysis).map { |product| row(product, actual: actuals.fetch(product.id, 0)) }
    end

    def character_totals(rows)
      Character.order(:age_band, :id).map do |character|
        aggregate(character, rows.select { |row| eligible_analysis?(row.analysis) && row.analysis.character_id == character.id })
      end
    end

    def concept_totals(rows)
      totals = %w[peer_fit motion_fit privacy other].map do |angle|
        aggregate(angle, rows.select { |row| eligible_analysis?(row.analysis) && row.analysis.concept_angle == angle })
      end
      totals << aggregate("미지정", rows.select { |row| row.analysis&.manually_assigned? && row.analysis.concept_angle.blank? })
    end

    def actual_for(product_id)
      actuals_by_product.fetch(product_id, 0)
    end

    private

    def eligible_analysis?(analysis)
      analysis && (analysis.status == "done" || analysis.manually_assigned?)
    end

    def actuals_by_product
      Order.where(status: %w[paid shipped delivered])
        .where(created_at: assumptions.fetch("period_days").days.ago..)
        .group(:product_id).sum(:total_price)
    end

    def aggregate(label, rows)
      target = rows.sum { |row| row.target_revenue.to_d }
      actual = rows.sum { |row| row.actual_revenue.to_d }
      { label: label, products: rows.size, target: target, actual: actual,
        achievement: achievement(actual, target) }
    end
  end
end
