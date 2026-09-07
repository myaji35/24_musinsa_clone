import { Controller } from "@hotwired/stimulus"
import { Html5Qrcode } from "html5-qrcode"

// Connects to data-controller="barcode-scanner"
export default class extends Controller {
  static targets = ["video", "result", "manualInput", "scanButton"]
  static values = {
    autoRedirect: { type: Boolean, default: false },
    redirectUrl: String
  }

  connect() {
    console.log("Barcode scanner controller connected")
    this.isScanning = false
    this.lastDetectedCode = null
    this.detectionCount = 0
    this.requiredDetections = 3 // 3번 연속 동일한 바코드 감지 시 확정
  }

  disconnect() {
    this.stopScanning()
  }

  // 스캔 시작
  startScanning() {
    if (this.isScanning) return

    this.isScanning = true
    this.updateUI("scanning")

    this.scanner = new Html5Qrcode(this.videoTarget.id)
    this.scanner.start(
      { facingMode: "environment" },
      { fps: 10, qrbox: undefined },
      (decodedText, decodedResult) => {
        this.onDetected({ codeResult: { code: decodedText, decodedCodes: decodedResult } })
      },
      () => {}
    ).catch((err) => {
      this.isScanning = false
      console.error("Html5Qrcode 초기화 실패:", err)
      this.handleError("카메라 접근 실패. 권한을 확인해주세요.")
    })
  }

  // 스캔 중지
  stopScanning() {
    if (!this.isScanning) return

    this.isScanning = false
    this.scanner.stop().then(() => this.scanner.clear()).catch(() => {})
    this.updateUI("idle")
    console.log("스캔 중지")
  }

  // 바코드 감지 콜백
  onDetected(result) {
    const code = result.codeResult.code

    console.log("바코드 감지:", code, "정확도:", result.codeResult.decodedCodes)

    // 연속 감지 로직 (오감지 방지)
    if (code === this.lastDetectedCode) {
      this.detectionCount++
    } else {
      this.lastDetectedCode = code
      this.detectionCount = 1
    }

    // 3번 연속 동일 코드 감지 시 확정
    if (this.detectionCount >= this.requiredDetections) {
      this.onBarcodeConfirmed(code)
      this.detectionCount = 0
      this.lastDetectedCode = null
    }
  }

  // 바코드 확정 처리
  onBarcodeConfirmed(code) {
    console.log("바코드 확정:", code)

    // 햅틱 피드백 (모바일)
    if (navigator.vibrate) {
      navigator.vibrate(200)
    }

    // 결과 표시
    this.showResult(code)

    // 자동 리다이렉트 (옵션)
    if (this.autoRedirectValue && this.redirectUrlValue) {
      const url = new URL(this.redirectUrlValue, window.location.origin)
      url.searchParams.set("barcode", code)

      setTimeout(() => {
        window.location.href = url.toString()
      }, 500)
    }

    // 스캔 중지 (중복 감지 방지)
    this.stopScanning()
  }

  // 결과 표시
  showResult(code) {
    if (this.hasResultTarget) {
      this.resultTarget.innerHTML = `
        <div class="bg-green-50 border border-green-200 rounded-lg p-4 mb-4">
          <div class="flex items-center gap-3">
            <svg class="w-6 h-6 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"></path>
            </svg>
            <div>
              <p class="text-sm font-bold text-green-800">바코드 감지 성공</p>
              <p class="text-lg font-mono font-bold text-green-900 mt-1">${code}</p>
            </div>
          </div>
        </div>
      `
    }

    // 수동 입력 필드에도 값 설정
    if (this.hasManualInputTarget) {
      this.manualInputTarget.value = code
    }
  }

  // 에러 처리
  handleError(message) {
    this.updateUI("error")

    if (this.hasResultTarget) {
      this.resultTarget.innerHTML = `
        <div class="bg-red-50 border border-red-200 rounded-lg p-4 mb-4">
          <div class="flex items-center gap-3">
            <svg class="w-6 h-6 text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
            </svg>
            <p class="text-sm font-medium text-red-800">${message}</p>
          </div>
        </div>
      `
    }
  }

  // UI 상태 업데이트
  updateUI(state) {
    const videoContainer = this.videoTarget.parentElement

    switch (state) {
      case "scanning":
        videoContainer.classList.remove("hidden")
        if (this.hasScanButtonTarget) {
          this.scanButtonTarget.textContent = "스캔 중지"
          this.scanButtonTarget.classList.remove("bg-black")
          this.scanButtonTarget.classList.add("bg-red-600")
        }
        break

      case "idle":
        videoContainer.classList.add("hidden")
        if (this.hasScanButtonTarget) {
          this.scanButtonTarget.textContent = "카메라로 스캔"
          this.scanButtonTarget.classList.remove("bg-red-600")
          this.scanButtonTarget.classList.add("bg-black")
        }
        break

      case "error":
        videoContainer.classList.add("hidden")
        if (this.hasScanButtonTarget) {
          this.scanButtonTarget.textContent = "다시 시도"
          this.scanButtonTarget.classList.remove("bg-red-600")
          this.scanButtonTarget.classList.add("bg-black")
        }
        break
    }
  }

  // 토글 (시작/중지)
  toggle() {
    if (this.isScanning) {
      this.stopScanning()
    } else {
      this.startScanning()
    }
  }

  // 수동 입력 제출
  submitManual(event) {
    event.preventDefault()

    if (this.hasManualInputTarget) {
      const code = this.manualInputTarget.value.trim()

      if (code) {
        this.onBarcodeConfirmed(code)
      }
    }
  }
}
