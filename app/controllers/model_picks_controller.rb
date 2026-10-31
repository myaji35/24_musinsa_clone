class ModelPicksController < ApplicationController
  before_action :load_candidates

  def show
  end

  def create
    if @analysis.nil?
      redirect_to product_model_pick_path(@product), alert: "상품 분석이 없어 선택을 저장할 수 없습니다"
    elsif @rows.none? { |row| row[:character].id.to_s == params[:character_id].to_s }
      redirect_to product_model_pick_path(@product), alert: "업로드된 후보 모델을 선택해 주세요"
    else
      @analysis.update!(picked_character_id: params[:character_id], picked_at: Time.current)
      redirect_to product_model_pick_path(@product), notice: "모델을 선택했습니다"
    end
  end

  private

  def load_candidates
    @product = Product.find(params[:product_id])
    @analysis = @product.product_analyses.order(created_at: :desc, id: :desc).first
    ranking = begin
      value = JSON.parse(@analysis&.ranking_json.presence || "[]")
      value.is_a?(Array) ? value.select { |entry| entry.is_a?(Hash) } : []
    rescue JSON::ParserError
      []
    end
    uploads = ContentUpload.where(product: @product, kind: "cut").includes(:character).order(:created_at, :id)
    uploads = uploads.includes(:file_attachment) if action_name == "show"
    groups = uploads.group_by(&:character)
    @rows = groups.map do |character, uploads|
      index = ranking.index { |entry| entry["handle"] == character.handle }
      { character: character, uploads: uploads.index_by(&:slot), rank: index && index + 1,
        reason: index && ranking[index]["reason"] }
    end.sort_by { |row| row[:rank] || Float::INFINITY }.first(3)
  end
end
