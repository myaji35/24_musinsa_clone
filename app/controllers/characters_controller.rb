class CharactersController < ApplicationController
  skip_before_action :require_admin, only: :show

  def show
    @character = Character.find_by!(handle: params[:handle])
    @products = @character.worn_products.with_attached_image.includes(:reviews).order(created_at: :desc)
    @recommended_products = @character.recommended_products if @products.empty?
    @similar_characters = @character.similar_characters if @recommended_products&.empty?
  end
end
