class KpiController < ApplicationController
  def index
    calculator = Kpi::Calculator.new
    @rows = calculator.rows
    @target = @rows.sum { |row| row.target_revenue.to_d }
    @actual = @rows.sum { |row| row.actual_revenue.to_d }
    @achievement = calculator.achievement(@actual, @target)
    @status_counts = @rows.filter_map { |row| row.analysis&.status }.tally
    @cost = ProductAnalysis.sum(:cost_usd)
    @character_totals = calculator.character_totals(@rows)
    @concept_totals = calculator.concept_totals(@rows)
  end
end
