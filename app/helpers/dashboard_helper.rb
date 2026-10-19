module DashboardHelper
  def daily_sales_bar_style(revenue, maximum)
    height = maximum.positive? ? revenue.to_f / maximum * 100 : 0
    "height: #{height}%; min-height: #{revenue.positive? ? 4 : 0}px"
  end
end
