module Ledger
  class Balance
    def initialize(account, supplier = nil)
      @account = account
      @suppliers = account.suppliers.order(:name)
      @suppliers = @suppliers.where(id: supplier.id) if supplier
    end

    def partners
      @partners ||= build_partners
    end

    def build_partners
      entries_by_supplier = @account.ledger_entries.where(supplier_id: @suppliers.select(:id)).order(:occurred_on, :id).group_by(&:supplier_id)
      @suppliers.map do |supplier|
        entries = entries_by_supplier.fetch(supplier.id, [])
        credit = entries.select { |e| e.entry_type == "receipt" }.sum(&:amount)
        # 조정은 매출 잔액에 반영한다. 음수 조정은 수금과 같이 오래된 매출부터 상계한다.
        adjustment = entries.select { |e| e.entry_type == "adjustment" }.sum(&:amount)
        credit -= adjustment if adjustment.negative?
        outstanding = entries.select { |e| e.entry_type == "sale" }.filter_map do |entry|
          applied = [ credit, entry.amount ].min
          credit -= applied
          remaining = entry.amount - applied
          { entry: entry, supplier: supplier, remaining: remaining, bucket: bucket(entry.due_on) } if remaining.positive? && entry.due_on
        end
        payment = entries.select { |e| e.entry_type == "payment" }.sum(&:amount)
        payables_outstanding = entries.select { |e| e.entry_type == "purchase" }.filter_map do |entry|
          applied = [ payment, entry.amount ].min
          payment -= applied
          remaining = entry.amount - applied
          { entry: entry, supplier: supplier, remaining: remaining, bucket: bucket(entry.due_on) } if remaining.positive? && entry.due_on
        end
        { supplier: supplier, payables_outstanding: payables_outstanding, receivable: entries.sum(&:receivable_change), payable: entries.sum(&:payable_change), outstanding: outstanding,
          next_due_on: outstanding.map { |row| row[:entry].due_on }.min }
      end
    end

    def totals
      { receivable: partners.sum { |row| row[:receivable] }, payable: partners.sum { |row| row[:payable] } }
    end

    def receivables
      partners.flat_map { |row| row[:outstanding] }.sort_by { |row| [ row[:entry].due_on, row[:entry].id ] }.group_by { |row| row[:bucket] }
    end

    def payables
      partners.flat_map { |row| row[:payables_outstanding] }.sort_by { |row| [ row[:entry].due_on, row[:entry].id ] }.group_by { |row| row[:bucket] }
    end

    private

    def bucket(date)
      return unless date
      return "예정일 지남" if date < Date.current

      date <= Date.current + 7 ? "7일 이내" : "이후"
    end
  end
end
