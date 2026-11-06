class WorkspaceLedgerController < ApplicationController
  skip_before_action :require_admin
  before_action :require_account_member
  before_action :set_partner, only: [ :show, :create_entry, :edit_entry, :update_entry, :destroy_entry ]
  before_action :set_entry, only: [ :edit_entry, :update_entry, :destroy_entry ]

  def index
    @balance = Ledger::Balance.new(current_account)
  end

  def receivables
    balance = Ledger::Balance.new(current_account)
    @groups = balance.receivables
    @payables_groups = balance.payables
  end

  def new
    @partner = current_account.suppliers.new
  end

  def create
    @partner = current_account.suppliers.new(params.require(:supplier).permit(:name, :kind, :phone, :business_number))
    if @partner.save
      redirect_to workspace_ledger_partner_path(@partner)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @entry = current_account.ledger_entries.new(supplier: @partner, occurred_on: Date.current)
    load_entries
  end

  def create_entry
    @entry = current_account.ledger_entries.new(entry_params.merge(supplier: @partner, created_by_user: current_user))
    if @entry.save
      redirect_to workspace_ledger_partner_path(@partner)
    else
      load_entries
      render :show, status: :unprocessable_entity
    end
  end

  def edit_entry
  end

  def update_entry
    if @entry.update(entry_params)
      redirect_to workspace_ledger_partner_path(@partner)
    else
      render :edit_entry, status: :unprocessable_entity
    end
  end

  def destroy_entry
    @entry.destroy!
    redirect_to workspace_ledger_partner_path(@partner)
  end

  private

  def set_partner
    @partner = current_account.suppliers.find(params[:id])
  end

  def set_entry
    @entry = current_account.ledger_entries.where(supplier: @partner).find(params[:entry_id])
  end

  def load_entries
    @entries = current_account.ledger_entries.where(supplier: @partner).order(:occurred_on, :id)
  end

  def entry_params
    params.require(:ledger_entry).permit(:entry_type, :occurred_on, :item_name, :quantity, :unit, :unit_price, :amount, :due_on, :memo)
  end
end
