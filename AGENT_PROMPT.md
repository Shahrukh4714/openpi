# OpenPi - Master Project Brief for AI Agents

## 1. Project Overview
We are building **OpenPi**, a free, open-source, Cursor-quality AI code editor designed for developers and students (especially in price-sensitive markets like India).
Instead of paying $20/month for proprietary tools like Cursor or Windsurf, users get a full-featured desktop IDE with:
- **Forever Free & BYOK (Bring Your Own Key):** Users can paste keys from 60+ providers (OpenAI, Anthropic, Google Gemini, DeepSeek, Groq, local Ollama).
- **OpenPi Go Tier (₹299/month / ~$3.50):** An affordable hosted tier with instant UPI payment for users who want managed credits (using high-speed, cost-effective models like DeepSeek-V3/R1 and Gemini Flash).

## 2. Selected Architecture (updated 2026-08-26)

### Tech Stack:
- **Base Editor / Shell:** VSCodium-based fork of Code-OSS (Electron + TypeScript). All fork changes live in `patches/` - never edit upstream sources directly; keeps upstream merges cheap (the Cursor model).
- **Agent Backend:** The existing open-source **Pi Agent Harness** (`earendil-works/pi`, MIT, TypeScript) used *as a library* - specifically `@earendil-works/pi-ai` (unified multi-provider LLM API) and `@earendil-works/pi-agent-core` (agent runtime, tool calling, state).
  - NOTE: pi is TypeScript, NOT Rust as originally assumed. The "lightweight sidecar" story is preserved by Bun-compiling our wrapper into a standalone exe.
- **Sidecar:** `sidecar/` = thin JSON-RPC server (WebSocket on localhost + stdio fallback) wrapping the pi libraries. Spawned as a child process by the extension; health-checked; auto-restarted on crash.
- **UI Layer:** `extension/` = standard VS Code extension (chat sidebar webview, Ctrl+K inline widget, onboarding wizard, key manager). Works in any VS Code today; bundled into the fork installer.
- **Communication Protocol:** Local JSON-RPC over ws://127.0.0.1:<port>, newline-delimited JSON over stdio fallback.
- **Billing / Auth:** Razorpay (UPI AutoPay & one-time passes) for the ₹299/mo Go tier (later phase).

## 3. Key Core Features to Implement
1. **Onboarding wizard:** provider picker -> BYOK key paste OR Go Tier login -> first prompt in under 60 seconds. Zero config files.
2. **AI Chat Sidebar:** context-aware chat with @file/@codebase chips (clickable, not memorized syntax), streaming markdown, Apply buttons on code blocks.
3. **Inline Edit (Ctrl + K):** highlight code, trigger prompt, see inline green/red diffs, accept with Tab / reject with Esc.
4. **Multi-file agent activity view:** harness actions rendered as human-readable progress cards ("Reading src/app.ts...", "Editing 3 files...").
5. **Key & Tier Manager:** settings panel to configure BYOK API keys or sign in to the Go tier; usage visible in rupees.

## 4. Product Principles
- **Beginner surface is the moat:** power users keep pi CLI; beginners get OpenPi. Same brain, two faces.
- Review-gated everything: no file writes without explicit user consent (Accept/Reject buttons).
- Keep ALL fork modifications as patches so rebasing on monthly VS Code releases stays manageable.

## 5. Current State & Roadmap
- Repo: C:\Users\shahr\Downloads\openpi
- Phase 1 (in progress): scaffold monorepo, clone VSCodium+vscode via scripts/setup-fork.ps1, rebranding patch set, full Windows installer pipeline.
- Phase 2: sidecar JSON-RPC bridge wrapping pi libs.
- Phase 3: extension UI (onboarding, chat sidebar, Ctrl+K, key manager).
- Phase 4: CI (GitHub Actions windows-latest), Open VSX publishing.
