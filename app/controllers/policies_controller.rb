class PoliciesController < ApplicationController
  skip_before_action :require_admin

  def returns
  end
end
