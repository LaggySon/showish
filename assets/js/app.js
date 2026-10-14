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
// browser source without leaving the page. The label reads "Copied" for two
// seconds, then goes back.
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
      // A named button ("Copy the Scorebug URL") says Copied to a screen reader too.
      const original = this.el.dataset.originalLabel || this.el.textContent
      const originalName = this.el.dataset.originalName || this.el.getAttribute("aria-label")
      this.el.dataset.originalLabel = original
      if (originalName) {
        this.el.dataset.originalName = originalName
        this.el.setAttribute("aria-label", "Copied")
      }
      this.el.textContent = "Copied"
      clearTimeout(this.resetTimer)
      this.resetTimer = setTimeout(() => {
        this.el.textContent = original
        if (originalName) { this.el.setAttribute("aria-label", originalName) }
      }, 2000)
    })
  },
  destroyed() { clearTimeout(this.resetTimer) }
}

// The System / Light / Dark radio group in the top bar. The choice itself is
// applied by the script in root.html.heex; this marks the current one and moves
// it with the arrow keys (a roving tabindex, DESIGN.md section 7.3).
const ThemePicker = {
  mounted() {
    this.options = [...this.el.querySelectorAll("[role=radio]")]
    this.mark(localStorage.getItem("phx:theme") || "system")
    this.el.addEventListener("click", (event) => {
      const option = event.target.closest("[role=radio]")
      if (option) { this.choose(option) }
    })
    this.el.addEventListener("keydown", (event) => {
      const step = {ArrowRight: 1, ArrowDown: 1, ArrowLeft: -1, ArrowUp: -1}[event.key]
      if (!step) { return }
      event.preventDefault()
      const index = this.options.indexOf(document.activeElement)
      this.choose(this.options[(index + step + this.options.length) % this.options.length])
    })
    this.onStorage = (event) => event.key === "phx:theme" && this.mark(event.newValue || "system")
    window.addEventListener("storage", this.onStorage)
  },
  choose(option) {
    option.dispatchEvent(new Event("phx:set-theme", {bubbles: true}))
    this.mark(option.dataset.phxTheme)
    option.focus()
  },
  mark(theme) {
    for (const option of this.options) {
      const on = option.dataset.phxTheme === theme
      option.setAttribute("aria-checked", String(on))
      option.tabIndex = on ? 0 : -1
    }
  },
  destroyed() { window.removeEventListener("storage", this.onStorage) }
}

// "saved 4s ago" after an autosave (DESIGN.md section 7.7). The server sets
// data-saved-at (milliseconds) after each write; this keeps the age current.
const SavedAge = {
  mounted() {
    this.render()
    this.timer = setInterval(() => this.render(), 1000)
  },
  updated() { this.render() },
  render() {
    const savedAt = Number(this.el.dataset.savedAt)
    if (!savedAt) { return }
    const seconds = Math.max(0, Math.floor((Date.now() - savedAt) / 1000))
    const age =
      seconds < 60 ? `${seconds}s` :
      seconds < 3600 ? `${Math.floor(seconds / 60)}m` :
      `${Math.floor(seconds / 3600)}h`
    this.el.textContent = `saved ${age} ago`
    this.el.title = new Date(savedAt).toLocaleString()
  },
  destroyed() { clearInterval(this.timer) }
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, OverlayScale, ClipboardCopy, ThemePicker, SavedAge},
})

// Confirmation dialog (DESIGN.md sections 7.16 and 12.5). phoenix_html asks
// window.confirm() for every [data-confirm] control; this answers first, with
// the native <dialog> in root.html.heex. data-confirm holds the question,
// data-confirm-body the consequence and data-confirm-action the verb on the
// danger button. Cancel has the focus, so Enter never destroys anything.
const confirmDialog = document.getElementById("confirm-dialog")
if (confirmDialog) {
  let opener = null
  let confirmed = null
  window.addEventListener("phoenix.link.click", (event) => {
    const control = event.target
    const question = control.getAttribute && control.getAttribute("data-confirm")
    if (!question) { return }
    // Keep phoenix_html's window.confirm() from asking a second time.
    event.stopImmediatePropagation()
    if (control === confirmed) {
      confirmed = null
      return
    }
    event.preventDefault()
    opener = control
    document.getElementById("confirm-dialog-title").textContent = question
    document.getElementById("confirm-dialog-body").textContent = control.dataset.confirmBody || ""
    document.getElementById("confirm-dialog-ok").textContent = control.dataset.confirmAction || "Confirm"
    confirmDialog.showModal()
  }, true)
  document.getElementById("confirm-dialog-cancel").addEventListener("click", () => confirmDialog.close())
  document.getElementById("confirm-dialog-ok").addEventListener("click", () => {
    confirmDialog.close()
    if (opener && opener.isConnected) {
      confirmed = opener
      opener.click()
    }
  })
  confirmDialog.addEventListener("close", () => {
    if (opener && opener.isConnected) { opener.focus() }
    opener = null
  })
}

// Menus are <details class="ui-menu">, which do not close by themselves: close
// them on a click outside and on Escape (DESIGN.md section 7.15).
document.addEventListener("click", (event) => {
  for (const menu of document.querySelectorAll("details.ui-menu[open]")) {
    if (!menu.contains(event.target)) { menu.open = false }
  }
})
document.addEventListener("keydown", (event) => {
  if (event.key !== "Escape") { return }
  for (const menu of document.querySelectorAll("details.ui-menu[open]")) {
    menu.open = false
    menu.querySelector("summary").focus()
  }
})

// A slow navigation keeps the old page on screen under a static "Loading…"
// overlay (DESIGN.md section 7.14). Nothing moves; fast navigations show nothing.
// A lost connection also starts a page load ("error"); the connection notice
// covers that one, so only navigations get the overlay.
let loadingTimer = null
window.addEventListener("phx:page-loading-start", (event) => {
  if (!["redirect", "patch"].includes(event.detail.kind)) { return }
  clearTimeout(loadingTimer)
  loadingTimer = setTimeout(() => {
    const main = document.getElementById("main")
    if (!main || main.querySelector(".app-loading-overlay")) { return }
    main.setAttribute("aria-busy", "true")
    const overlay = document.createElement("div")
    overlay.className = "ui-region-overlay app-loading-overlay"
    overlay.setAttribute("role", "status")
    overlay.textContent = "Loading…"
    main.appendChild(overlay)
  }, 300)
})
window.addEventListener("phx:page-loading-stop", () => {
  clearTimeout(loadingTimer)
  const main = document.getElementById("main")
  if (!main) { return }
  main.removeAttribute("aria-busy")
  main.querySelectorAll(".app-loading-overlay").forEach((overlay) => overlay.remove())
})

const setOptimisticNumber = (selector, value, minimum = 0, maximum = Number.MAX_SAFE_INTEGER) => {
  const element = document.querySelector(selector)
  if (!element) { return }
  const next = Math.max(minimum, Math.min(maximum, value))
  element.textContent = String(next)
}

const bumpOptimisticNumber = (selector, delta, minimum = 0, maximum = Number.MAX_SAFE_INTEGER) => {
  const element = document.querySelector(selector)
  if (!element) { return }
  const current = Number.parseInt(element.textContent, 10) || 0
  setOptimisticNumber(selector, current + delta, minimum, maximum)
}

// A base is a toggle: aria-pressed is both its state and its look.
const setOptimisticBase = (button, occupied) => {
  if (!button) { return }
  button.setAttribute("aria-pressed", String(occupied))
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
// connected operator. The acknowledgement is a color change only: the button
// shows pressed for a moment (DESIGN.md section 8: nothing moves).
document.addEventListener("click", event => {
  const button = event.target.closest("#control-room button")
  if (!button || button.disabled) { return }

  predictControlAction(button)
  button.classList.add("shortcut-confirmed")
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

