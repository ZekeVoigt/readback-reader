# Readback Reader

Readback Reader is a free, offline-first macOS menu-bar app that reads selected text aloud with better voice and speed controls.

I built it for a real accessibility problem: chatbot and coding-assistant outputs can be long, dense, and hard to process visually, especially for dyslexic readers. Readback Reader makes it easier to select a response in Codex, VS Code, a browser, or another app and hear it spoken back.

The project also includes a lightweight local VS Code extension prototype.

## Features

- Read selected text with `Option-Command-R`
- Stop reading with `Option-Command-S`
- Read the clipboard from the menu
- Choose one of four curated macOS voices
- Choose speed from `0.5x` to `2.0x`
- Works offline and uses built-in macOS voices
- No paid text-to-speech API required

## Project structure

```text
.
├── Package.swift
├── Sources/ReadbackReader/main.swift
├── scripts/build-app.sh
└── vscode-extension/
    ├── extension.js
    └── package.json
```

## Build

Requirements:

- macOS 13 or newer
- Swift toolchain / Xcode Command Line Tools

```sh
./scripts/build-app.sh
```

The app will be created at:

```text
dist/Readback Reader.app
```

## Run

Open the app:

```sh
open "dist/Readback Reader.app"
```

You will see `Readback` in the macOS menu bar.

## Permissions

For `Option-Command-R` to read selected text, macOS needs Accessibility permission because the app simulates `Command-C`.

If the hotkey does not read selected text, go to:

```text
System Settings > Privacy & Security > Accessibility
```

Then enable `Readback Reader`.

The fallback always works: copy text normally, then choose `Read Clipboard` from the menu.

The app intentionally refuses to read old clipboard text when selected-text copying fails.

## VS Code Extension

There is also a simple local VS Code extension in:

```text
vscode-extension
```

It adds these commands:

- `Readback: Read Selection`
- `Readback: Read Clipboard`
- `Readback: Stop Reading`
- `Readback: Choose Speed`
- `Readback: Choose Voice`

To try it during development, open the `vscode-extension` folder in VS Code and press `F5` to launch an Extension Development Host.

The default VS Code hotkeys are:

- `Option-Command-R` to read the current editor selection
- `Option-Command-S` to stop reading

## Roadmap

- Package the macOS app with a signed release build
- Package the VS Code extension as a `.vsix`
- Add a small preferences window
- Add optional keyboard shortcut customization

## License

MIT
