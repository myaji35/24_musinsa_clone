class CharactersController < ApplicationController
  skip_before_action :require_admin, only: :show

  def show
    @character = Character.find_by!(handle: params[:handle])
    @products = @character.worn_products.with_attached_image.order(created_at: :desc)
  end
end
