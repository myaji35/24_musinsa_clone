require "vips"

module SheetPipeline
  class ModelRecommender
    def initialize(fetcher: nil, client: nil)
      @fetcher = fetcher || ImageFetcher.new
      @client = client
    end

    def call(row)
      return if row["추천 모델"].present?

      url = row["이미지"].to_s.lines.first.to_s.strip
      bytes = @fetcher.call(url)
      image = Vips::Image.new_from_buffer(bytes, "")
      ratio = [ 1024.0 / [ image.width, image.height ].max, 1.0 ].min
      image = image.resize(ratio) if ratio < 1
      image = image.flatten(background: [ 255, 255, 255 ]) if image.has_alpha?
      jpeg = image.write_to_buffer(".jpg")
      details = { code: row["상품코드"], name: row["상품명"], price_color: row["가격·색상"] }
      appeal_points = (1..3).filter_map { |number| row["소구포인트#{number}"].to_s.strip.presence }
      ranking = ProductAnalyses::Analyzer.rank_for_sheet(details: details, image_jpeg: jpeg,
        appeal_points: appeal_points, client: @client)

      { "추천 모델" => ranking.map { |entry| "#{entry[:rank]}. #{entry[:name]} — #{entry[:reason]}" }.join("\n"),
        "상태" => "추천완료" }
    end
  end
end
