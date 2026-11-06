class WorkspaceController < ApplicationController
  skip_before_action :require_admin
  before_action :require_account_member

  def show
    @users = current_account.users.order(:id)
  end
end
