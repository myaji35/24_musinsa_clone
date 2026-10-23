class SearchController < ApplicationController
  skip_before_action :require_admin, only: [ :index ]
  def index
    redirect_to root_path(q: params[:q].presence), status: :moved_permanently
  end
end
