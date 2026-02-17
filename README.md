# Speak

A native macOS app for seamless PDF + video presentations. Built with **SwiftUI**, **PDFKit**, and **AVKit** — the same rendering stack as Preview.app, so PDF quality is pixel-perfect on Retina displays.

---

## Features

- 📄 Renders PDF pages using Apple's native PDFKit (same engine as Preview.app)
- 🎬 Plays video (MP4, MOV, M4V) via AVKit — hardware accelerated
- ⚡️ Seamless sequence: PDF pages → video → remaining PDF pages
- ⌨️ Keyboard navigation (→ / Space to advance, ← to go back, Esc to exit fullscreen)
- 🖥️ Full-screen support
- 🔲 Auto-advances after video finishes
- HUD controls auto-hide after 3 seconds

---

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15 or later

---

## Setup

### 1. Open in Xcode

```bash
open Speak.xcodeproj
```

### 2. Set your signing team

In Xcode → click **Speak** in the project navigator → **Signing & Capabilities** → set your **Team** (your Apple ID is fine for personal use).

### 3. Build & Run

Press **⌘R** or click the ▶ button.

---

## How to Use

1. On launch, you'll see the **Setup screen**
2. Click **PDF File** to pick your PDF
3. Click **Video File** to pick your video (MP4, MOV, M4V, AVI)
4. Set the **"Insert video after page"** number (default: 5)
   - Setting it to `5` means: pages 1–5, then video, then page 6 onwards
5. Click **Start Presentation**

### Navigation

| Key | Action |
|-----|--------|
| `→` or `Space` | Next slide |
| `←` | Previous slide |
| `Esc` | Exit full screen |
| Mouse move | Show HUD controls |

The video plays automatically when reached and auto-advances to the next PDF page when it finishes.

---

## Customization

The core logic lives in **`PresentationSequence.swift`**. The sequence is defined as:

```swift
PresentationSequence(
    pdfURL: pdf,
    videoURL: video,
    videoAfterPage: 5   // insert video after page 5
)
```

You can extend `Slide` enum and `PresentationSequence` to support multiple videos, reordering, or looping — the architecture is designed to be easy to extend.

---

## File Structure

```
Speak/
├── Speak.xcodeproj/
└── Speak/
    ├── Sources/
    │   ├── SpeakApp.swift       # App entry point
    │   ├── ContentView.swift           # Root view (setup ↔ presentation switch)
    │   ├── PresentationSequence.swift  # Sequence model (PDF pages + video)
    │   ├── PresentationViewModel.swift # State & navigation logic
    │   ├── PDFPageView.swift           # Native PDF renderer (PDFKit)
    │   ├── VideoSlideView.swift        # AVKit video player
    │   ├── SlideStageView.swift        # Main presentation stage + HUD
    │   └── SetupView.swift             # File picker + config UI
    └── Speak.entitlements       # App sandbox permissions
```

---

## Why Better Than Python?

Python PDF viewers typically render at 72 DPI and don't account for Retina displays. This app uses Apple's **PDFKit**, which renders vector PDF content at native screen resolution using the GPU — identical to Preview.app. There's no pixel quality compromise.
