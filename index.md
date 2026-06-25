---
title: Speak — Native macOS Presentation App
layout: default
---

# Speak

A native macOS app for building and delivering presentations from PDFs, videos, and images — with live drawing and hotkey-driven branching.

Built entirely on Apple frameworks (**SwiftUI**, **PDFKit**, **AVKit**, **AppKit**) with no external dependencies.

## Key features

- **Plan-based sequencing** — mix PDF page ranges, videos, and images into one portable `.speakplan` file
- **Per-action hotkeys** — bind single keys to jump, replay, skip, play a detour clip, or go back mid-presentation
- **Live drawing** — pen and highlighter overlay with undo; strokes scale correctly at any window size or in fullscreen
- **Native rendering** — PDFKit for vector-sharp PDFs at Retina resolution, AVKit for hardware-accelerated video
- **File associations** — double-click a `.speakplan` to open the editor; double-click a `.pdf` to present all pages immediately

## Requirements

- macOS 14 (Sonoma) or later
- Xcode 15 or later

## Build & run

```bash
open Speak.xcodeproj
# Set signing team in Xcode → Speak target → Signing & Capabilities
# Press ⌘R
```

## Keyboard shortcuts (presentation mode)

| Key | Action |
|-----|--------|
| `→` / `↓` / `Space` | Next slide |
| `←` / `↑` | Previous slide |
| `Esc` | Toggle fullscreen |
| `P` | Toggle pen |
| `H` | Toggle highlighter |
| `⌘Z` | Undo last stroke |
| any bound key | Fire configured hotkey |

---

[View full README and source on GitHub](https://github.com/amessbee/speak)
