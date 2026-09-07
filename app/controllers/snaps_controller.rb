class SnapsController < ApplicationController
  skip_before_action :require_admin, only: [ :index, :show ]
  def index
    @snaps = Snap.includes(:user).order(id: :desc)
  end

  def new
  end

  def create
  end

  def show
  end
end
