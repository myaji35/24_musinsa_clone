class WorkspaceScheduleController < ApplicationController
  skip_before_action :require_admin
  before_action :require_account_member
  before_action :set_event, only: [ :edit, :update, :complete, :destroy ]

  def index
    @supplier = current_account.suppliers.find(params[:supplier_id]) if params[:supplier_id].present?
    @month = Date.iso8601("#{params[:month]}-01") if params[:month].present?
    @month ||= Date.current.beginning_of_month
    @list = params[:view] == "list"
    @from, @to = @list ? [ Date.current, Date.current + 13 ] : [ @month, @month.end_of_month ]
    @items = Schedule::Feed.new(current_account, from: @from, to: @to, supplier: @supplier).call
    @by_date = @items.group_by(&:starts_on)
    @overdue_items = Schedule::Feed.overdue(current_account, supplier: @supplier)
  rescue Date::Error
    redirect_to workspace_schedule_path
  end

  def new
    @event = current_account.schedule_events.new(starts_on: Date.current)
  end

  def create
    @event = current_account.schedule_events.new(event_params.merge(created_by_user: current_user))
    if @event.save
      redirect_to workspace_schedule_path
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @event.update(event_params)
      redirect_to workspace_schedule_path
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def complete
    @event.update!(status: "done")
    redirect_to workspace_schedule_path
  end

  def destroy
    @event.destroy!
    redirect_to workspace_schedule_path
  end

  private

  def set_event
    @event = current_account.schedule_events.find(params[:id])
  end

  def event_params
    attributes = params.require(:schedule_event).permit(:title, :starts_on, :starts_at_time, :kind, :status, :memo, :supplier_id)
    current_account.suppliers.find(attributes[:supplier_id]) if attributes[:supplier_id].present?
    attributes
  end
end
