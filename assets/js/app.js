// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/showish"
import topbar from "../vendor/topbar"

// Overlays are authored on a fixed 1920x1080 canvas so that what the operator
// sees in the preview is pixel-identical to what the broadcast software
// composites. In a 1920x1080 browser source the scale is exactly 1; anywhere
// smaller (the control room preview, a phone) it shrinks to fit.
const OverlayScale = {
  mounted() {
    this.fit = () => {
      const scale = Math.min(1, window.innerWidth / 1920, window.innerHeight / 1080)
      this.el.style.transform = `scale(${scale})`
    }
    this.fit()
    window.addEventListener("resize", this.fit)
  },
  updated() { this.fit() },
  destroyed() { window.removeEventListener("resize", this.fit) }
}

// Copies the overlay URL next to it, so an operator can paste straight into a
// browser source without leaving the page.
const ClipboardCopy = {
  mounted() {
    this.el.addEventListener("click", async () => {
      const text = this.el.dataset.clipboardText
      if (!text) { return }
      try {
        await navigator.clipboard.writeText(text)
      } catch (_error) {
        const scratch = document.createElement("textarea")
        scratch.value = text
        document.body.appendChild(scratch)
        scratch.select()
        document.execCommand("copy")
        scratch.remove()
      }
      const original = this.el.dataset.originalLabel || this.el.textContent
      this.el.dataset.originalLabel = original
      this.el.textContent = "Copied"
      clearTimeout(this.resetTimer)
      this.resetTimer = setTimeout(() => { this.el.textContent = original }, 1200)
    })
  },
  destroyed() { clearTimeout(this.resetTimer) }
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, OverlayScale, ClipboardCopy},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

const optimisticTimer = new WeakMap()

const markOptimistic = element => {
  if (!element) { return }
  element.classList.remove("optimistic-value")
  window.requestAnimationFrame(() => element.classList.add("optimistic-value"))
  window.clearTimeout(optimisticTimer.get(element))
  optimisticTimer.set(element, window.setTimeout(() => {
    element.classList.remove("optimistic-value")
  }, 1100))
}

const setOptimisticNumber = (selector, value, minimum = 0, maximum = Number.MAX_SAFE_INTEGER) => {
  const element = document.querySelector(selector)
  if (!element) { return }
  const next = Math.max(minimum, Math.min(maximum, value))
  element.textContent = String(next)
  markOptimistic(element)
}

const bumpOptimisticNumber = (selector, delta, minimum = 0, maximum = Number.MAX_SAFE_INTEGER) => {
  const element = document.querySelector(selector)
  if (!element) { return }
  const current = Number.parseInt(element.textContent, 10) || 0
  setOptimisticNumber(selector, current + delta, minimum, maximum)
}

const setOptimisticBase = (button, occupied) => {
  if (!button) { return }
  button.setAttribute("aria-pressed", String(occupied))
  button.classList.toggle("optimistic-base-occupied", occupied)
  button.classList.toggle("optimistic-base-empty", !occupied)
}

const predictControlAction = button => {
  const click = button.getAttribute("phx-click")
  const action = button.getAttribute("phx-value-action")

  if (click === "score") {
    const position = button.getAttribute("phx-value-position")
    const delta = Number.parseInt(button.getAttribute("phx-value-delta"), 10) || 0
    const prefix = button.closest("#baseball-controls") ? "#baseball-runs-" : "#score-value-"
    bumpOptimisticNumber(`${prefix}${position}`, delta)
    return
  }

  if (action === "adjust_count") {
    const kind = button.getAttribute("phx-value-kind")
    const delta = Number.parseInt(button.getAttribute("phx-value-delta"), 10) || 0
    bumpOptimisticNumber(`#baseball-${kind}`, delta, 0, kind === "balls" ? 3 : 2)
    return
  }

  if (action === "adjust_pitch_count") {
    const position = button.getAttribute("phx-value-position")
    const delta = Number.parseInt(button.getAttribute("phx-value-delta"), 10) || 0
    bumpOptimisticNumber(`#baseball-pitches-${position}`, delta)
    return
  }

  if (action === "toggle_base") {
    setOptimisticBase(button, button.getAttribute("aria-pressed") !== "true")
    return
  }

  if (action === "clear_count") {
    setOptimisticNumber("#baseball-balls", 0)
    setOptimisticNumber("#baseball-strikes", 0)
    return
  }

  if (action === "clear_bases") {
    document.querySelectorAll("#baseball-controls [id^='baseball-base-']")
      .forEach(base => setOptimisticBase(base, false))
    return
  }

  if (action === "record_pitch") {
    const fieldingPosition = document.querySelector("#baseball-live-state")?.dataset.fieldingPosition
    if (fieldingPosition) { bumpOptimisticNumber(`#baseball-pitches-${fieldingPosition}`, 1) }

    const result = button.getAttribute("phx-value-result")
    const balls = Number.parseInt(document.querySelector("#baseball-balls")?.textContent, 10) || 0
    const strikes = Number.parseInt(document.querySelector("#baseball-strikes")?.textContent, 10) || 0

    if (result === "ball") {
      if (balls === 3) {
        setOptimisticNumber("#baseball-balls", 0)
        setOptimisticNumber("#baseball-strikes", 0)
      } else {
        setOptimisticNumber("#baseball-balls", balls + 1, 0, 3)
      }
    } else if (result === "strike") {
      if (strikes === 2) {
        setOptimisticNumber("#baseball-balls", 0)
        setOptimisticNumber("#baseball-strikes", 0)
        bumpOptimisticNumber("#baseball-outs", 1, 0, 2)
      } else {
        setOptimisticNumber("#baseball-strikes", strikes + 1, 0, 2)
      }
    } else if (result === "foul" && strikes < 2) {
      setOptimisticNumber("#baseball-strikes", strikes + 1, 0, 2)
    }
    return
  }

  if (button.closest("#baseball-play-form") && button.type === "submit") {
    setOptimisticNumber("#baseball-balls", 0)
    setOptimisticNumber("#baseball-strikes", 0)
  }
}

// Every control-room shortcut acknowledges the operator and predicts simple
// counters immediately. The next LiveView patch remains authoritative and
// naturally reconciles any prediction affected by baseball rules or another
// connected operator.
document.addEventListener("click", event => {
  const button = event.target.closest("#control-room button")
  if (!button || button.disabled) { return }

  predictControlAction(button)
  button.classList.remove("shortcut-confirmed")
  window.requestAnimationFrame(() => button.classList.add("shortcut-confirmed"))
  window.setTimeout(() => button.classList.remove("shortcut-confirmed"), 300)
})

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", _e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}

