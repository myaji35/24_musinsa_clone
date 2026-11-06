class MagazineController < ApplicationController
  skip_before_action :require_admin

  def index
    @issues = MagazineIssue.visible(admin: mall_admin?)
  end

  def show
    @issue = MagazineIssue.visible(admin: mall_admin?).find { |issue| issue.number.to_s == params[:issue] }
    @article = @issue&.article(params[:slug])
    raise ActiveRecord::RecordNotFound unless @article
  end
end
