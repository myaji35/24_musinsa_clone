class MyController < ApplicationController
  skip_before_action :require_admin
  before_action :require_login

  def show
  end

  def orders
  end
end
