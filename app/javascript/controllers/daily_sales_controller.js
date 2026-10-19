import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["detail"]

  select(event) {
    this.detailTarget.textContent = event.currentTarget.getAttribute("aria-label")
  }
}
