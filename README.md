# OpenPi

A free, open-source, Cursor-quality AI code editor for developers and students.
Built as a [VSCodium](https://vscodium.com)-based fork of VS Code with the
[Pi Agent Harness](https://github.com/earendil-works/pi) powering the AI backend.

**The pitch:** Pi is a powerful terminal-first coding agent. OpenPi gives it a face —
a full IDE where someone who has never opened a terminal can paste an API key,
describe what they want in plain language, and review every change as a visual diff.

## Highlights

- **Forever Free / BYOK** — bring keys from OpenAI, Anthropic, Gemini, DeepSeek, Groq, Ollama, and more (via `pi-ai`)
- **OpenPi Go Tier** — ₹299/month hosted credits (DeepSeek-V3/R1, Gemini Flash) payable via UPI/Razorpay
- **AI Chat Sidebar** — `@file` / `@codebase` context, streaming responses, tool-call cards in plain language
- **Inline Edit (Ctrl+K)** — select code, describe the change, review the diff
- **Review-gated edits** — nothing touches disk without an explicit Accept

## Repository layout

```
openpi/
├── patches/vscodium/   # Fork changes applied over upstream VS Code source (never edit upstream directly)
├── product/            # product.json overrides (branding, telemetry-off)
├── scripts/            # setup-fork.ps1, build-installer.ps1, dev.ps1
├── sidecar/            # openpi-sidecar: local JSON-RPC daemon wrapping pi-ai + pi-agent-core
└── extension/          # openpi-ui: chat sidebar, onboarding wizard, Ctrl+K, key manager
```

## Building (Windows)

```powershell
# 1. Clone upstream sources and apply patches (~10-20 min)
./scripts/setup-fork.ps1

# 2. Build installer artifacts
./scripts/build-installer.ps1
```

## License

MIT — see [LICENSE](LICENSE). Upstream projects (vscode, VSCodium, pi) are MIT licensed.
