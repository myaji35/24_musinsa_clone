class SnapsController < ApplicationController
  skip_before_action :require_admin, only: [ :index, :show ]
  def index
    @snaps = Snap.includes(:user).order(id: :desc)
  end

  def show
    @snap = Snap.includes(:user).find(params[:id])
    @products = Product.published.where(id: SnapProduct.where(snap_id: @snap.id).select(:product_id)).with_attached_image
  end
end
