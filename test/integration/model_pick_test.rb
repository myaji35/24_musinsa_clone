require "test_helper"

class ModelPickTest < ActionDispatch::IntegrationTest
  setup do
    @product = products(:one)
  end

  test "login required for viewing and selecting" do
    get product_model_pick_path(@product)
    assert_redirected_to login_path
    post product_model_pick_path(@product), params: { character_id: 1 }
    assert_redirected_to login_path
  end

  test "empty state" do
    sign_in
    get product_model_pick_path(@product)
    assert_response :success
    assert_includes response.body, "아직 올라온 컷 이미지가 없습니다"
  end

  test "three ranked rows with nine cuts and selection persistence" do
    characters = create_cuts
    analysis = @product.product_analyses.create!(ranking_json: characters.reverse.map { |c| { handle: c.handle, reason: "추천 이유 #{c.name}" } }.to_json)
    sign_in
    get product_model_pick_path(@product)
    assert_response :success
    assert_select "section", count: 3
    assert_select "section img", count: 9
    assert_select "section:first-of-type h2", text: /1위 · 모델2/
    assert_includes response.body, "추천 이유 모델2"
    post product_model_pick_path(@product), params: { character_id: characters.last.id }
    assert_redirected_to product_model_pick_path(@product)
    assert_equal characters.last.id, analysis.reload.picked_character_id
    assert analysis.picked_at
    follow_redirect!
    assert_select "span", text: "선택됨"
    post product_model_pick_path(@product), params: { character_id: -1 }
    assert_equal characters.last.id, analysis.reload.picked_character_id
  end

  test "no analysis does not create one and upload order is used" do
    create_cuts
    @product.product_analyses.destroy_all
    sign_in
    get product_model_pick_path(@product)
    assert_select "section:first-of-type h2", text: /모델0/
    assert_no_difference("ProductAnalysis.count") do
      post product_model_pick_path(@product), params: { character_id: Character.last.id }
    end
    assert flash[:alert]
  end

  private

  def create_cuts
    3.times.map do |i|
      character = Character.create!(name: "모델#{i}", handle: "pick-#{i}")
      3.times do |j|
        upload = ContentUpload.new(product: @product, character: character, kind: "cut", slot: j + 1, sha256: Digest::SHA256.hexdigest("#{i}-#{j}"))
        upload.file.attach(io: File.open(file_fixture("product.png")), filename: "cut.png", content_type: "image/png")
        upload.save!
      end
      character
    end
  end
end
