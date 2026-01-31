import { Controller } from "@hotwired/stimulus"

// Lazy loading images with Intersection Observer
export default class extends Controller {
  static values = {
    src: String,
    threshold: { type: Number, default: 0.1 }
  }

  connect() {
    this.observer = new IntersectionObserver(
      (entries) => this.handleIntersection(entries),
      {
        rootMargin: "50px",
        threshold: this.thresholdValue
      }
    )

    this.observer.observe(this.element)
  }

  disconnect() {
    this.observer.disconnect()
  }

  handleIntersection(entries) {
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        this.loadImage()
        this.observer.unobserve(this.element)
      }
    })
  }

  loadImage() {
    const src = this.srcValue || this.element.dataset.src

    if (!src) return

    // Support for <picture> element with WebP
    if (this.element.tagName === "IMG") {
      this.element.src = src
      this.element.classList.add("loaded")
    } else if (this.element.tagName === "DIV") {
      // Background image
      this.element.style.backgroundImage = `url(${src})`
      this.element.classList.add("loaded")
    }

    // Remove data-src after loading
    delete this.element.dataset.src
  }
}
