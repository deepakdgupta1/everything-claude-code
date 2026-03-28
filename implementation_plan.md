# Goal Description

Enhance the capabilities of "Everything Claude Code" (ECC) AI Agents by integrating advanced, context-aware rule execution paradigms and granular technology stacks inspired by the `awesome-cursorrules` repository (`idea-source`). This will elevate ECC agents from language-level assistants to highly specialized, framework-aware workflow orchestrators.

## User Review Required

> [!IMPORTANT]
> A central paradigm shift proposed here is implementing **Glob-based Dynamic Rules (MDC)**. This requires injecting new Node.js hooks into `ecc/scripts/hooks` to process files dynamically as the agent interacts with them. Please review the "Open Questions" before we proceed.

## Proposed Changes

---

### 1. Context-Aware Rule Triggering System (Glob-based MDC)

**Finding:** Cursor's modern rules (`rules-new/*.mdc`) use `globs: **/*.tsx, components/**/*` to conditionally trigger guidelines *only* when the agent is editing relevant files. This prevents context bloat and hallucination. ECC currently loads broad language principles universally across the workspace (e.g., `rules/typescript/coding-style.md`).

**Proposed Implementation:**
- [NEW] Script `ecc/scripts/hooks/inject-mdc-context.js` that hooks into `PreToolUse` (specifically for `Edit`, `Write`, `Read` tools).
- [MODIFY] `ecc/hooks/hooks.json`: Add a hook that parses `.mdc` files, validates glob paths against the files being touched, and dynamically feeds the specific constraints to the agent output stream, guaranteeing ultra-specific context.

---

### 2. Granular Framework & Library Specialization Layer

**Finding:** Cursor's power stems from highly specialized combos (e.g., `nextjs15-react19-vercelai-tailwind`, `python-fastapi-scalable-api`). ECC's static rules focus mostly on base languages (`python`, `golang`, `typescript`). Real-world coding requires framework idioms, not just syntax idioms.

**Proposed Implementation:**
- [NEW] Directories `ecc/rules/frameworks/` and `ecc/rules/libraries/`.
- [NEW] Migrate the high-value constraints from `idea-source/rules-new/*.mdc` (like `react.mdc`, `nextjs.mdc`, `fastapi.mdc`, `tailwind.mdc`, `database.mdc`) into ECC.
- [MODIFY] `ecc/rules/README.md`: Document the new multidimensional hierarchy (`common/` -> `language/` -> `framework/`).

---

### 3. Domain-Specific Agent Personas Expansion

**Finding:** `idea-source` leverages extensive project management and QA-specific context rules (e.g., `engineering-ticket-template`, `playwright-accessibility-testing`). ECC has `planner.md` and `e2e-runner.md` but they lack the structured depth of these specific Cursor templates.

**Proposed Implementation:**
- [MODIFY] `ecc/agents/e2e-runner.md`: Inject explicit web accessibility (a11y) checking steps, ARIA compliance flows, and defect tracking checklists gathered from Cursor's Cypress/Playwright rules.
- [MODIFY] `ecc/agents/planner.md`: Overhaul the planning step to embed structured epic/ticket formulation loops to increase code predictability.

---

### 4. Technology-to-MCP Auto-Mapping

**Finding:** Cursor rules heavily prescribe native interactions with tool chains (Vercel, Supabase, Cloudflare). ECC exposes these individually in `mcp-configs/mcp-servers.json` but they aren't bound to the active toolchain context.

**Proposed Implementation:**
- [MODIFY] `ecc/scripts/hooks/session-start.js`: Implement a capability scanner that reviews `package.json`/`requirements.txt` and automatically outputs a recommendation to the agent (e.g., "Detected Vercel and Next.js. Ensure `vercel` MCP server is enabled from configs").

## Open Questions

> [!WARNING]
> Please verify the following before we begin execution:

1. **Glob / MDC Implementation:** Should the new `.mdc` parser dynamically rewrite `CLAUDE.md` to persist the specific framework rules, OR should it inject them strictly at runtime during file operations via `hooks.json` standard output?
2. **Framework Rules Scope:** Shall we directly port all 18 generic MDC files from `idea-source/rules-new/` to `ecc/rules/frameworks/`, or would you prefer a selected subset (e.g. React/Next/Tailwind/FastAPI) to start?

## Verification Plan

### Automated Tests
- Run `.agents/ecc/scripts/ci/run-tests.sh` (if applicable) to ensure new hooks don't break agent execution.
- Validate `ecc/hooks/hooks.json` syntax explicitly using JSON parser.

### Manual Verification
- Execute an `Agent` test session inside ECC to ensure that touching a React component dynamically prints the specific React best-practices into the tool stream warning logs, without flooding context on Python files.
