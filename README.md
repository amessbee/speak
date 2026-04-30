# Speak

A native macOS presentation app for sequencing PDFs, videos, and images into a single interactive slideshow — with live drawing tools and hotkey-driven branching.

Built entirely on Apple frameworks: **SwiftUI**, **PDFKit**, **AVKit**, **AppKit**. PDF pages render at native Retina resolution using the same engine as Preview.app, with no external dependencies.

---

## Features

- **Plan-based sequencing** — compose any mix of PDF page ranges, videos, and images into an ordered plan saved as a portable `.speakplan` file
- **Per-action hotkeys** — bind single-character keys to jump, replay, skip, go back, or play a detour clip mid-presentation
- **Live drawing** — pen and highlighter overlay during presentation; strokes stay anchored when you resize or go fullscreen
- **Native rendering** — PDFKit for vector-sharp PDFs, AVKit for hardware-accelerated video, NSImage for stills
- **File associations** — double-click a `.speakplan` to open it in the editor; double-click a `.pdf` to present all pages immediately
- **Dark-first UI** — HUD controls auto-hide after 3 seconds; fullscreen toggle built in

---

## Requirements

- macOS 14 (Sonoma) or later
- Xcode 15 or later

---

## Building

### Development (run from Xcode)

```bash
open Speak.xcodeproj
```

Set your signing team in **Xcode → Speak target → Signing & Capabilities**, then press **⌘R**.

### Release build (install to /Applications)

```bash
xcodebuild -project Speak.xcodeproj -scheme Speak \
           -configuration Release \
           -derivedDataPath build/DerivedData build

cp -R build/DerivedData/Build/Products/Release/Speak.app /Applications/
```

Register file associations and clear the icon cache so Finder picks them up immediately:

```bash
/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/\
LaunchServices.framework/Versions/Current/Support/lsregister \
  -f -R -trusted /Applications/Speak.app

rm -rf ~/Library/Caches/com.apple.iconservices.store
killall Dock Finder
```

---

## How to Use

### 1. Workspace

On launch you see the three-panel **Workspace**:

| Panel | Purpose |
|-------|---------|
| Left sidebar — Sources | Add and name your media files |
| Centre — Plan | Build the sequence of actions |
| Top toolbar | New / Open / Save / Present |

### 2. Add source files

Click **+** in the Sources panel and pick one or more files. Speak accepts:

| Type | Formats |
|------|---------|
| PDF | `.pdf` |
| Video | `.mov`, `.mp4`, `.m4v`, `.avi` |
| Image | `.png`, `.jpg`, `.jpeg`, `.heic`, `.tiff`, `.gif`, `.bmp`, `.webp` |

Each file gets an auto-generated alias (`pdf1`, `video1`, `image2`, …). Click the alias to rename it — this is how actions reference the file.

### 3. Build a plan

Click **+** in the Plan panel to add an action. Three action types are available:

| Action | What it does |
|--------|-------------|
| **PDF Slides** | Show a range of pages from a PDF source |
| **Video** | Play a video source to completion, then auto-advance |
| **Image** | Show a static image |

For PDF Slides, choose a page range:

- All pages
- First N pages
- From page N onward
- Custom range (start – end)

### 4. Add hotkeys (optional)

Inside the action editor, add any number of hotkeys. Each hotkey is a single character you press during the presentation:

| Hotkey action | Behaviour |
|---------------|-----------|
| Jump to page N | Jump within the action's PDF range |
| Replay from start | Restart the current item (video or page) |
| Play detour | Play a video/image then return to current position |
| Skip to next action | Jump past the rest of this action |
| Go back to previous action | Jump back to the start of the previous action |

### 5. Save your plan

**⌘S** saves to the current `.speakplan` file. **Shift+⌘S** prompts for a new location. Plans are human-readable JSON and can be committed to version control.

### 6. Present

Click **Present** (or double-click a `.speakplan` in Finder). Navigation:

| Key | Action |
|-----|--------|
| `→` `↓` or `Space` | Next slide |
| `←` `↑` | Previous slide |
| `Esc` | Toggle fullscreen |
| Mouse move | Show / refresh HUD controls |
| Any bound hotkey | Trigger the configured action |

Active hotkeys for the current slide are shown in a hint bar above the HUD.

### 7. Quick-present a PDF

Drag a `.pdf` onto the app icon, or open a PDF with Speak from Finder's "Open With" menu. Speak auto-creates a plan for all pages and enters presentation mode immediately — no setup required.

---

## Drawing Tools

Press **P** (pen) or **H** (highlighter) during a presentation to activate drawing. A compact tool panel slides in from the right edge.

| Control | Options |
|---------|---------|
| **Pen colors** | White, yellow, red, orange, green, cyan, blue, black |
| **Pen widths** | 2, 5, 10, 18 px |
| **Highlighter colors** | Yellow, green, cyan, pink, orange, lavender |
| **Highlighter widths** | 10, 20, 30, 40 px |
| **Undo** | `⌘Z` — removes the last stroke |
| **Clear** | Wipes all strokes on the current slide |

Strokes are stored in normalised coordinates and scale correctly when you resize the window or toggle fullscreen.

Press **P** or **H** again to exit drawing mode.

---

## Keyboard Shortcuts — Full Reference

### Workspace

| Shortcut | Action |
|----------|--------|
| `⌘N` | New plan |
| `⌘O` | Open plan |
| `⌘S` | Save plan |
| `⇧⌘S` | Save As |

### Presentation

| Shortcut | Action |
|----------|--------|
| `→` / `↓` / `Space` | Next slide |
| `←` / `↑` | Previous slide |
| `Esc` | Toggle fullscreen |
| `P` | Toggle pen tool |
| `H` | Toggle highlighter |
| `⌘Z` | Undo last stroke |
| any bound key | Fire configured hotkey |

---

## Plan File Format

`.speakplan` files are UTF-8 JSON. They are portable as long as the media paths they reference remain accessible.

```json
{
  "version": 1,
  "sources": [
    { "id": "…", "alias": "deck", "path": "/abs/path/deck.pdf", "kind": "pdf" },
    { "id": "…", "alias": "intro", "path": "/abs/path/intro.mp4", "kind": "video" }
  ],
  "actions": [
    {
      "type": "pdfSlides",
      "payload": {
        "id": "…",
        "sourceAlias": "deck",
        "range": { "type": "firstN", "n": 10 },
        "hotkeys": [
          { "key": "r", "action": { "type": "replayFromStart" } },
          { "key": "d", "action": { "type": "playDetour", "alias": "intro" } }
        ]
      }
    }
  ]
}
```

---

## File Structure

```
Speak/
├── Speak.xcodeproj/
├── make_icon.swift          # Generates AppIcon.icns (run once)
├── make_doc_icon.swift      # Generates SpeakDoc.icns (run once)
└── Speak/
    ├── Info.plist           # Bundle metadata + file associations
    ├── Assets.xcassets/     # App icon + accent colour
    ├── SpeakDoc.icns        # Document icon for .speakplan files
    └── Sources/
        ├── SpeakApp.swift              # App entry + AppDelegate (URL open handling)
        ├── AppState.swift              # Shared state: pending open URLs
        ├── ContentView.swift           # Root: workspace ↔ presentation switch
        ├── Plan.swift                  # Plan data model + Codable
        ├── PlanExecutor.swift          # Compile plan → flat ExecutableItem list
        ├── PresentationViewModel.swift # Navigation, hotkey dispatch, detour logic
        ├── PresentationSequence.swift  # Slide enum (pdfPage / video / image)
        ├── WorkspaceView.swift         # Three-panel editor shell
        ├── SourcePanelView.swift       # Source file list + add/rename/delete
        ├── PlanPanelView.swift         # Action list + reorder/delete
        ├── ActionEditorSheet.swift     # Modal action editor + hotkey builder
        ├── SlideStageView.swift        # Presentation stage + HUD + key monitor
        ├── PDFPageView.swift           # PDFKit page renderer
        ├── VideoSlideView.swift        # AVKit video player
        ├── ImageSlideView.swift        # NSImage still renderer
        ├── DrawingOverlayView.swift    # Normalised-coordinate stroke canvas
        ├── DrawingViewModel.swift      # Stroke storage + undo stack
        ├── DrawingToolPanel.swift      # Floating pen/highlighter picker
        └── Extensions.swift            # Colour + helper extensions
```
