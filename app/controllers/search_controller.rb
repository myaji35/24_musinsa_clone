class SearchController < ApplicationController
  skip_before_action :require_admin, only: [ :index ]
  def index
  end
end
