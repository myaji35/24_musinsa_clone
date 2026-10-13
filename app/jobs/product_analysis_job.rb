class ProductAnalysisJob < ApplicationJob
  def perform(analysis_id)
    ProductAnalyses::Analyzer.call(ProductAnalysis.find(analysis_id))
  end
end
