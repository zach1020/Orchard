# Orchard

<p align="center"><img src="Sources/Orchard/Resources/OrchardLogo.png" width="160" alt="Orchard logo"></p>

A native Mac chat app built around Apple's on-device Foundation Models, inspired by the idea behind Apfel. This is an original SwiftUI implementation using Apple's framework and the official MCP Swift SDK.

## Run

Open `../Orchard.app`. Requires an Apple silicon Mac running macOS 26 or later with Apple Intelligence enabled and its model downloaded. This build is locally ad-hoc signed, not notarized or published.

## Included

- Custom cyan-and-magenta glass leaf logo, integrated into the app and macOS icon. See [logo provenance and prompt](Assets/LOGO.md).
- OLED-black appearance with native Liquid Glass panels, cyan and magenta accents, and high-contrast conversation text.
- Streaming local chat with a stop button and explicit model-availability status.
- A calculator tool with visible execution results.
- Brave web search, with links in the Sources panel. Enter your own Brave Search API key in Settings, then turn on Web search. Keys are stored in macOS Keychain. Search queries go to Brave; local inference does not become a cloud-model request.
- MCP connections through local stdio processes or HTTP endpoints (HTTPS, or localhost HTTP). Tool discovery and per-call approval. Optional HTTP bearer tokens stay in memory.
- Activity panel with tool calls and returned text.

## Try MCP without credentials

Open Settings and select Local process. Set executable to `/usr/bin/python3`. Set arguments to a JSON array containing the absolute path to `Examples/calculator_server.py` in this project. Click Connect & discover tools, then Done.

Ask: “Use multiply_numbers to multiply 137 by 29.” Approve the MCP call. The result should be 3973.

Launching a local MCP server runs that executable with your user permissions. Connect servers you trust. The app does not expose arbitrary shell execution as a built-in model tool.

## Build and test

Requires Xcode with Swift 6.2 or later and the macOS 26+ SDK. From this directory:

```sh
./build-app.sh
swift test --build-system native
ORCHARD_LIVE_TEST=1 swift test --build-system native
```

The live test asks the actual on-device model to invoke the calculator. Other tests cover malformed arguments, search-result decoding, and an actual MCP subprocess handshake and tool call, including declined calls.

## Prototype limits

- Chats, MCP settings, and bearer tokens stay in memory and clear on quit. The Brave key persists in Keychain.
- One connected MCP server and at most 12 discovered tools at a time. Complex schemas can exceed the local model's context budget.
- MCP tools receive a JSON argument object generated from their advertised schema. Server-side validation remains necessary. Only text results are currently passed to the model.
- OAuth, MCP resources/prompts, attachments, and persistent conversation history are not implemented.
- Tool configuration changes start a fresh model session; the visible conversation remains on screen but is not replayed into the new session. Use New chat for a clean slate.
- Context overflow is surfaced as an error; automatic summarization and trimming are not implemented.
- Web search needs your own key or a search MCP server. No live Brave request was tested without a key. Search-response decoding is covered by tests.
- Connection attempts time out. Stop cancels generation and disconnects an active MCP client to release pending calls.

## Dependencies

MCP Swift SDK and its transitive dependencies are managed by Swift Package Manager; versions are pinned in Package.resolved. Their source licenses are included in the package checkouts. No Apfel source code is included.

## Verification

Tested locally on an Apple silicon Mac running macOS 27.0.1. The live model invoked the calculator and produced 3973 for 137 × 29. A GUI MCP session discovered the bundled demo tool, showed the approval sheet, and returned 943 for 23 × 41. One initial GUI connection timed out; retry succeeded. HTTP transport is implemented using the official SDK but has not been verified against an external server.
