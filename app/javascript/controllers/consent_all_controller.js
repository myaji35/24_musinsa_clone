import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["all", "item"]

  connect() {
    this.sync()
  }

  toggleAll() {
    this.itemTargets.forEach(item => { item.checked = this.allTarget.checked })
  }

  sync() {
    const checked = this.itemTargets.filter(item => item.checked).length
    this.allTarget.checked = checked === this.itemTargets.length
    this.allTarget.indeterminate = checked > 0 && checked < this.itemTargets.length
  }
}
