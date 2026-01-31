import { Controller } from "@hotwired/stimulus"

// Epic 9.1: Lazy Loading Images with Intersection Observer
export default class extends Controller {
  static targets = ["image"]

  connect() {
    this.setupObserver()
    this.observeImages()
  }

  disconnect() {
    if (this.observer) {
      this.observer.disconnect()
    }
  }

  setupObserver() {
    const options = {
      root: null, // viewport
      rootMargin: "50px", // Load 50px before entering viewport
      threshold: 0.01
    }

    this.observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          this.loadImage(entry.target)
          this.observer.unobserve(entry.target)
        }
      })
    }, options)
  }

  observeImages() {
    // Observe all lazy images
    const lazyImages = document.querySelectorAll('img.lazy')
    lazyImages.forEach(img => {
      this.observer.observe(img)
    })
  }

  loadImage(img) {
    const src = img.dataset.src
    if (!src) return

    // Create a new image to preload
    const tempImage = new Image()
    tempImage.onload = () => {
      img.src = src
      img.classList.remove('lazy')
      img.classList.add('loaded')
    }
    tempImage.src = src
  }
}
