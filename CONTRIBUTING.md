# Contributing

Readback Reader is an early personal accessibility project. Small, focused improvements are welcome.

## Local development

Build the macOS menu-bar app:

```sh
./scripts/build-app.sh
```

Run it:

```sh
open "dist/Readback Reader.app"
```

Check the VS Code extension JavaScript:

```sh
node --check vscode-extension/extension.js
```

## Notes

- Keep the app free and offline-first.
- Avoid paid text-to-speech APIs in the default path.
- Keep voice and speed controls simple enough for daily use.
- Do not commit `.build`, `dist`, or packaged extension artifacts.
