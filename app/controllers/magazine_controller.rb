class MagazineController < ApplicationController
  skip_before_action :require_admin

  def index
    @issues = MagazineIssue.visible(admin: logged_in?)
  end

  def show
    @issue = MagazineIssue.visible(admin: logged_in?).find { |issue| issue.number.to_s == params[:issue] }
    @article = @issue&.article(params[:slug])
    raise ActiveRecord::RecordNotFound unless @article
  end
end
