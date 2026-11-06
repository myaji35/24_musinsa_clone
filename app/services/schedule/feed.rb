module Schedule
  class Feed
    Item = Data.define(:title, :starts_on, :starts_at_time, :kind, :status, :event, :source_path)

    def self.overdue(account, supplier: nil, days: 90)
      today = Date.current
      new(account, from: today - days, to: today - 1, supplier: supplier, overdue: true).call
    end

    def initialize(account, from:, to:, supplier: nil, overdue: false)
      @account, @from, @to, @supplier, @overdue = account, from, to, supplier, overdue
    end

    def call
      events = @account.schedule_events.where(starts_on: @from..@to)
      events = events.where(status: "open") if @overdue
      suppliers = @account.suppliers
      if @supplier
        events = events.where(supplier_id: @supplier.id)
        suppliers = suppliers.where(id: @supplier.id)
      end
      items = events.map do |event|
        Item.new(title: event.title, starts_on: event.starts_on, starts_at_time: event.starts_at_time,
          kind: event.kind, status: event.status, event: event, source_path: nil)
      end
      PurchaseOrder.pending.where(supplier_id: suppliers.select(:id), expected_delivery_date: automatic_dates).each do |order|
        items << automatic("입고 #{timing_label} #{order.order_number}", order.expected_delivery_date, "delivery", paths.purchase_order_path(order))
      end
      Ledger::Balance.new(@account, @supplier).partners.each do |partner|
        { "수금" => partner[:outstanding], "지급" => partner[:payables_outstanding] }.each do |label, rows|
          rows.each do |row|
            next unless automatic_dates.cover?(row[:entry].due_on)

            amount = ActiveSupport::NumberHelper.number_to_delimited(row[:remaining].round)
            items << automatic("#{label} #{timing_label} #{partner[:supplier].name} #{amount}원", row[:entry].due_on, "payment", paths.workspace_ledger_partner_path(partner[:supplier]))
          end
        end
      end
      items.sort_by { |item| [ item.starts_on, item.starts_at_time&.strftime("%H:%M:%S") || "", item.title ] }
    end

    private

    def automatic_dates
      @overdue ? (..@to) : (@from..@to)
    end

    def timing_label
      @overdue ? "지연" : "예정"
    end

    def paths
      Rails.application.routes.url_helpers
    end

    def automatic(title, date, kind, path)
      Item.new(title: title, starts_on: date, starts_at_time: nil, kind: kind, status: "open", event: nil, source_path: path)
    end
  end
end
