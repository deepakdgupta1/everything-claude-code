# **Gemini CLI Configuration & Attribute Specification**

## **1. Identity & Classification**

* **Agent Name**: Gemini CLI
* **Vendor/Maintainer**: Google (google-gemini)
* **Release Channel**: General Availability (Stable, Preview, Nightly available)
* **Primary Form Factor**: CLI Tool (Terminal-based Agent)
* **License Model**: Open Source (Apache 2.0)
* **Cost Architecture**:
  * Free Tier: 60 requests/min, 1,000 requests/day with personal Google account
  * Paid Tiers: Google AI Pro, Google AI Ultra, or Google Developer Program premium for higher limits

---

## **2. Cognitive Architecture (The "Brain")**

* **Default Foundation Model**: **Gemini 3 Pro**
* **Supported Model Families**:
  * Gemini 3 Pro (Flagship, advanced reasoning)
  * Gemini 3 Flash (Speed-optimized)
  * Gemini 2.5 Pro (Previous generation, strong reasoning)
* **Reasoning Effort**: High; incorporates internal "thinking process" with configurable `thinkingLevel` parameter for reasoning depth control
* **Context Window**: **1 Million Tokens** (input), 65,536 tokens (output)
* **Planning Mode**: **Adaptive (ReAct Loop)**. Uses a "reason and act" pattern—plans, executes tools, observes results, iterates
* **Self-Correction Capability**: High. Iterative debugging via test execution and linter feedback. Can retry failed operations and self-correct based on tool output
* **Orchestration Pattern**: Single-threaded ReAct loop with conversation checkpointing for session persistence

---

## **3. Operational Environment (The "Body")**

* **Host Compatibility**: macOS (Apple Silicon/Intel), Linux (x86/ARM), Windows
* **Installation Method**:
  * `npx @google/gemini-cli` (No global installation required)
  * `npm install -g @google/gemini-cli` (Global install)
  * `brew install gemini-cli` (macOS/Linux via Homebrew)
  * Anaconda environment for restricted systems
  * Pre-installed in Google Cloud Shell
* **Configuration File Path**:
  * System Defaults: `/etc/gemini-cli/system-defaults.json` (Linux), `C:\ProgramData\gemini-cli\system-defaults.json` (Windows), `/Library/Application Support/GeminiCli/system-defaults.json` (macOS)
  * User Settings: `~/.gemini/settings.json`
  * Project Settings: `.gemini/settings.json`
  * System Override: `/etc/gemini-cli/settings.json` (Enterprise control)
* **Workspace Awareness**: CLI-based; aware of current working directory (CWD) and children. Uses GEMINI.md for project-specific context
* **Sandboxing Mechanism**:
  * **Disabled by default** (can be enabled)
  * Enable via: `--sandbox` flag, `GEMINI_SANDBOX` environment variable, or `settings.json` (`"tools": {"sandbox": true}`)
  * Supports Docker and Podman containers
  * Custom sandbox profiles via `.gemini/sandbox-macos-custom.sb` or `.gemini/sandbox.Dockerfile`
  * **Automatically enabled** when using `--yolo` or `--approval-mode=yolo`

---

## **4. Context & Memory (The "Knowledge")**

* **Context Configuration File**: **GEMINI.md**
  * Project-level: `./GEMINI.md` (or in `.gemini/` directory)
  * Global: `~/.gemini/GEMINI.md`
  * Also supports: **AGENTS.md** (vendor-neutral standard)
* **Indexing Strategy**: On-demand file reading + GEMINI.md context injection. Does not maintain a persistent vector database by default. Supports conversation checkpointing for session persistence
* **Global vs. Local Config**:
  * Precedence Order (lowest to highest):
    1. System Defaults (`/etc/gemini-cli/system-defaults.json`)
    2. User Settings (`~/.gemini/settings.json`)
    3. Project Settings (`.gemini/settings.json`)
    4. System Override (`/etc/gemini-cli/settings.json` - Enterprise enforcement)
  * GEMINI.md files are merged hierarchically (global + project)
* **Ignore Patterns**: Respects `.gitignore` by default
* **Artifact Generation**:
  * Direct file edits
  * Terminal output streams
  * Git commits
  * Conversation checkpoints (savepoints for resumption)

---

## **5. Tooling & Connectivity (The "Hands")**

* **Terminal Execution**: **Native**. Can execute shell commands directly in the user's terminal
* **Browser/Web Access**:
  * **Google Search Grounding**: Built-in capability to fetch real-time, external context from the web
  * **Web Fetching**: Can retrieve and process content from web pages
* **File System Access**: Read/Write access to CWD and project files
* **MCP (Model Context Protocol) Support**: **Native**
  * Configure MCP servers in `~/.gemini/settings.json`
  * Supports Stdio, SSE (Server-Sent Events), and Streamable HTTP transports
  * OAuth 2.0 authentication for remote MCP servers
  * Integrate with external services (Grafana, Prometheus, PagerDuty, Kubernetes, etc.)
* **Extension/Skill Ecosystem**:
  * Custom commands definable via GEMINI.md
  * MCP servers for custom tool integrations
  * GitHub Action integration (`google-github-actions/run-gemini-cli`) for:
    * Automated PR reviews
    * Issue triage and labeling
    * On-demand assistance via `@gemini-cli` mentions
    * Custom CI/CD workflows

---

## **6. Security & Governance (The "Guardrails")**

* **Execution Policy (Terminal)**:
  * Default: **Human-in-the-Loop**. Prompts user for permission on write operations and shell commands
  * Read-only tools are generally allowed without confirmation
  * **Trusted Folders**: Per-folder execution policy control via `security.folderTrust.enabled`
  * Policy Engine: Define custom rules in TOML files (`~/.gemini/policies/my-rules.toml`)
  * **YOLO Mode**: Bypass confirmations (requires sandboxing to be auto-enabled)
* **Execution Policy (Browser/Web)**:
  * Google Search grounding respects privacy settings
  * Configurable network access via policy engine
* **Network Access Control**:
  * Outbound to Google services required for model access
  * MCP server access configurable via allowlists
  * Secret redaction via `security.environmentVariableRedaction.enabled`
* **Secret Detection**:
  * Built-in environment variable redaction
  * `security.blockGitExtensions` to prevent extensions from Git repositories
  * Secure credential storage via OAuth or API key
* **Telemetry**: Configurable telemetry settings; usage data collected for product improvement
* **Additional Security Settings** (via `settings.json`):
  * `security.disableYoloMode`: Prevent accidental YOLO usage
  * `security.enablePermanentToolApproval`: Remember tool approval decisions
  * **Audit Trails**: All proposed actions logged for compliance

---

## **Deep Analysis of Gemini CLI Attributes**

### **The "Unix Philosophy" Terminal-First Design**

Unlike Google Antigravity's monolithic IDE approach, Gemini CLI embraces the "Unix Philosophy"—it is a composable, text-based tool designed for developers who operate primarily in the terminal. It does not attempt to replace the existing development environment but integrates seamlessly into it. This design philosophy prioritizes:

* **Composability**: Gemini CLI can be piped, scripted, and integrated into existing shell workflows and CI/CD pipelines
* **Lightweight footprint**: No heavyweight IDE required; operates directly in any terminal
* **Non-interactive mode**: Can run in scripts for automated workflows

### **The GEMINI.md Context Standard**

Gemini CLI popularized the GEMINI.md file as "Agent-Readable Documentation." This file serves as a condensed set of rules, commands, and architectural patterns that the agent ingests at startup. The hierarchical loading (global `~/.gemini/GEMINI.md` merged with project-level `./GEMINI.md`) reflects sophisticated "context economics"—maximizing token relevance within the 1M context window.

Additionally, Gemini CLI supports the vendor-neutral **AGENTS.md** standard, ensuring compatibility with other agents in the ecosystem and enabling repository portability.

### **Multi-Layer Security Model**

Gemini CLI implements a comprehensive security strategy with multiple defensive layers:

1. **Deterministic Tools**: Strictly typed tools with metadata indicating potential impact (safe, reversible, destructive)
2. **Risk Assessment**: High-risk actions are automatically flagged for review
3. **Policy Enforcement**: Configurable TOML-based rules for fine-grained control
4. **Human-in-the-Loop**: User confirmation required for sensitive operations by default
5. **Sandboxing**: Optional containerized execution for complete isolation

This "defense in depth" approach allows Gemini CLI to be used safely in both individual and enterprise environments.

### **Conversation Checkpointing and Token Caching**

Gemini CLI introduces sophisticated memory management through conversation checkpointing. Users can save and resume complex sessions, enabling:

* Long-running agent sessions that span multiple terminal sessions
* State preservation for iterative development workflows
* Token caching to optimize usage and reduce latency

### **Enterprise-Ready Configuration Management**

The layered configuration system (System Defaults → User Settings → Project Settings → System Override) mirrors enterprise MDM patterns. The System Override file (`/etc/gemini-cli/settings.json`) enforces organization-wide policies that cannot be overridden by individual users, enabling:

* Central control over security policies
* Consistent configuration across development teams
* Compliance with organizational security requirements

### **Native GitHub Integration**

Unlike other CLI agents that treat GitHub as an external tool, Gemini CLI has first-class GitHub integration via the official GitHub Action. This enables:

* Automated PR reviews with contextual feedback
* Issue triage and intelligent labeling
* On-demand assistance through `@gemini-cli` mentions
* Custom workflows integrated directly into GitHub CI/CD

---

## **Comparative Positioning**

| Attribute | Gemini CLI | Antigravity | Claude Code | Codex CLI |
|:----------|:-----------|:------------|:------------|:----------|
| **Form Factor** | CLI/Terminal | IDE (VS Code Fork) | CLI/Terminal | CLI/TUI |
| **Default Model** | Gemini 3 Pro | Gemini 3 Pro | Claude 3.5 Sonnet | GPT-5.2-Codex |
| **Context Window** | 1M tokens | 2M tokens | 200k-1M tokens | Variable |
| **Sandboxing** | Opt-in | Local/Docker | Local/Container | Strict Default |
| **Human-in-Loop** | Default (Ask) | Auto (Agent Decides) | Default (Ask) | Sandboxed |
| **Context File** | GEMINI.md | GEMINI.md/.agent/ | CLAUDE.md | AGENTS.md |
| **License** | Apache 2.0 | Proprietary | Proprietary | Apache 2.0 |
| **Cost (Individual)** | Free tier | Free (Preview) | Subscription | Subscription |
| **MCP Support** | Native | Native | Native | Native |

Gemini CLI occupies a unique position as Google's **open-source, terminal-first** answer to agentic coding. It shares DNA with Antigravity (same Gemini 3 models, same GEMINI.md context standard) but targets a different user persona: developers who prefer the command line over GUI-based IDEs.

---

## **Works Cited**

1. Gemini CLI GitHub Repository, accessed January 2026, https://github.com/google-gemini/gemini-cli
2. Gemini CLI Documentation, accessed January 2026, https://geminicli.com/docs/
3. Google Blog - Gemini CLI Announcement, accessed January 2026, https://blog.google
4. Gemini Code Assist Documentation, accessed January 2026, https://codeassist.google
5. AGENTS.md Standard, accessed January 2026, https://agents.md/
6. Google AI Developer Documentation, accessed January 2026, https://ai.google.dev/
7. Google Cloud Documentation, accessed January 2026, https://cloud.google.com/
8. Gemini 3 Model Announcement - Google DeepMind, accessed January 2026, https://deepmind.google
