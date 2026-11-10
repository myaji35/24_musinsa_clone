class PoliciesController < ApplicationController
  skip_before_action :require_admin

  def terms
  end

  def privacy
  end

  def returns
  end
end
