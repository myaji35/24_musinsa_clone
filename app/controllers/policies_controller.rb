class PoliciesController < ApplicationController
  skip_before_action :require_admin

  def privacy
  end

  def returns
  end
end
