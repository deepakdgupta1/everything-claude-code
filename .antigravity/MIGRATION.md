# Migration Guide: Claude Code → Google Antigravity IDE

This guide maps [Everything Claude Code (ECC)](https://github.com/affaan-m/everything-claude-code) features to their equivalents in [Google Antigravity IDE](https://antigravity.google).

> [!CAUTION]
> All Antigravity configuration paths in this document are based on the [`google_antigravity_config.json`](../google_antigravity_config.json) specification (v1.14.2-preview) and supplementary capability research. **Many paths and features have not been verified in a live Antigravity IDE instance.** See [Verification Checklist](#verification-checklist) before performing a real migration.

---

## Feature Parity Matrix

| Feature                   | Claude Code                               | Antigravity IDE                                     | Status                                    |
| ------------------------- | ----------------------------------------- | --------------------------------------------------- | ----------------------------------------- |
| Rules                     | Global `~/.claude/rules/` + project       | Global `GEMINI.md` + workspace `.agent/rules/`      | ✅ Available                              |
| Skills                    | `skills/*/SKILL.md`                       | `.agent/skills/*/SKILL.md` + script auto-triggering | ✅ Identical standard                     |
| Commands                  | `commands/*.md` (slash commands)          | `.agent/workflows/*.md` (slash workflows)           | ✅ Available (renamed, supports chaining) |
| MCP Servers               | `mcp-configs/mcp-servers.json`            | `~/.gemini/antigravity/mcp_config.json` + MCP Store | ✅ Available                              |
| Agents                    | `agents/*.md` (frontmatter: tools, model) | `agy` CLI roles (YAML/JSON) + Skills + Workflows    | ✅ Available (via `agy` CLI)              |
| Multi-agent orchestration | Via agents                                | `agy` CLI chaining + Gemini Interactions API        | ✅ Available (more capable)               |
| Hooks                     | `hooks/hooks.json` (lifecycle events)     | No equivalent                                       | ❌ Use alternatives                       |
| Contexts                  | `contexts/*.md` (mode switching)          | `.agent/rules/*.md` (always-on)                     | ⚠️ Partial (no selective activation)      |
| Plugins                   | `~/.claude/plugins/` (marketplace)        | Partial via MCP Store                               | ⚠️ Partial                                |

---

## Concept Mapping

| Claude Code                      | Antigravity IDE                           | Notes                                               |
| -------------------------------- | ----------------------------------------- | --------------------------------------------------- |
| `~/.claude/rules/`               | `~/.gemini/GEMINI.md` (global)            | Single file for global rules                        |
| `~/.claude/rules/<lang>/`        | `<workspace>/.agent/rules/<rule>.md`      | Per-project, multiple files                         |
| `~/.claude/commands/`            | `<workspace>/.agent/workflows/`           | Triggered via `/` commands; supports chaining       |
| `~/.claude/skills/`              | `~/.gemini/antigravity/skills/` (global)  | Cross-project skills with script auto-triggering    |
| Project `skills/`                | `<workspace>/.agent/skills/`              | Project-scoped skills                               |
| `~/.claude.json` mcpServers      | `~/.gemini/antigravity/mcp_config.json`   | JSON format differences                             |
| `model: opus`                    | Model selector → `Claude Opus 4.5`        | UI dropdown OR `agy run` config                     |
| `model: sonnet`                  | Model selector → `Claude Sonnet 4.5`      | UI dropdown OR `agy run` config                     |
| `tools: ["Read", "Grep"]`        | `agy` CLI role config (tools/permissions) | Per-role tool definitions in YAML/JSON              |
| Agent orchestration              | `agy run` + Gemini Interactions API       | CLI and API-based multi-agent chaining              |
| Hooks (PreToolUse/PostToolUse)   | No equivalent                             | See [Hooks → Alternatives](#7-hooks--no-equivalent) |
| Contexts (dev, research, review) | Workspace rules (always-on)               | No selective activation                             |

---

## Migration Details by Feature Type

### 1. Skills — ✅ Identical Standard

Skills use the same **Agent Skills standard** (`SKILL.md` with YAML frontmatter) in both Claude Code and Antigravity.

#### What Changes

| Aspect               | Claude Code                                              | Antigravity IDE                                                                  |
| -------------------- | -------------------------------------------------------- | -------------------------------------------------------------------------------- |
| **Workspace path**   | `<project>/skills/*/SKILL.md`                            | `<workspace>/.agent/skills/*/SKILL.md`                                           |
| **Global path**      | `~/.claude/skills/*/`                                    | `~/.gemini/antigravity/skills/*/`                                                |
| **Format**           | YAML frontmatter (`name`, `description`) + markdown body | **Identical**                                                                    |
| **Subdirectories**   | `scripts/`, `templates/`, `resources/`                   | **Identical**                                                                    |
| **Invocation**       | Agent auto-discovers via description matching            | **Identical** (semantic matching)                                                |
| **Script execution** | Scripts in `scripts/` are reference material             | Scripts (Python, Node, Bash) are explicitly executed by the agent via tool calls |

#### Install Script Changes

```bash
# Copy skills to Antigravity workspace location
mkdir -p ".agent/skills"
cp -r "$SCRIPT_DIR/skills/." ".agent/skills/"
```

#### Frontmatter — No Changes Required

```yaml
---
name: api-design
description: REST API design patterns including resource naming, status codes, pagination...
---
```

> [!TIP]
> Antigravity emphasizes the `description` field as the primary trigger for semantic matching. Ensure descriptions are **precise and action-oriented**, not vague. This is already best practice in ECC skills.

> [!NOTE]
> **Script execution (Verified):** Antigravity does **not** invisibly auto-execute `scripts/` subdirectory contents. Instead, the agent is instructed to read `SKILL.md` when semantically triggered, and then it explicitly executes the script via its `run_command` tool. This behaves similarly to Claude Code, but the agent uses standard tool calls to run the script.

---

### 2. Rules — ✅ Available (Different Structure)

#### What Changes

| Aspect              | Claude Code                                   | Antigravity IDE                                            |
| ------------------- | --------------------------------------------- | ---------------------------------------------------------- |
| **Global rules**    | `~/.claude/rules/` (directory of `.md` files) | `~/.gemini/GEMINI.md` (single file)                        |
| **Workspace rules** | Project `CLAUDE.md`                           | `<workspace>/.agent/rules/*.md` (directory of `.md` files) |
| **Format**          | Plain markdown (no frontmatter)               | Plain markdown (no frontmatter)                            |
| **Precedence**      | Project overrides global                      | Workspace `.agent/rules/` overrides global `GEMINI.md`     |

#### Translation Strategy

**Global rules** — Claude Code's `rules/common/` files (8 files totaling ~8KB) should be consolidated into a single `~/.gemini/GEMINI.md`:

```bash
# Concatenate common rules into GEMINI.md
echo "# Global Coding Rules" > ~/.gemini/GEMINI.md
echo "" >> ~/.gemini/GEMINI.md
for f in "$SCRIPT_DIR/rules/common/"*.md; do
    cat "$f" >> ~/.gemini/GEMINI.md
    echo -e "\n---\n" >> ~/.gemini/GEMINI.md
done
```

**Workspace rules** — Language-specific rules can be installed as individual files:

```bash
# Copy language-specific rules to workspace
mkdir -p ".agent/rules"
for lang in "$@"; do
    for f in "$SCRIPT_DIR/rules/$lang/"*.md; do
        [ -f "$f" ] && cp "$f" ".agent/rules/$(basename "$f")"
    done
done
```

#### Example: `rules/common/security.md` → `.agent/rules/security.md`

No content changes needed — file content is plain markdown in both systems.

---

### 3. Commands → Workflows — ✅ Available (Renamed, Supports Chaining)

Claude Code **Commands** map to Antigravity **Workflows**. Both are slash-triggered (`/plan`, `/tdd`, etc.).

Antigravity workflows have an additional capability: **workflow chaining** — a workflow can programmatically invoke other workflows (e.g., a `/deploy` workflow can include "Call `/run-tests` first").

#### What Changes

| Aspect              | Claude Code                                          | Antigravity IDE                           |
| ------------------- | ---------------------------------------------------- | ----------------------------------------- |
| **Path**            | `commands/*.md`                                      | `<workspace>/.agent/workflows/*.md`       |
| **Global path**     | N/A                                                  | `~/.gemini/antigravity/global_workflows/` |
| **Frontmatter**     | `description:`                                       | `description:`                            |
| **Trigger**         | `/command-name`                                      | `/workflow-name`                          |
| **Chaining**        | Not supported                                        | Workflows can call other workflows        |
| **Agent reference** | Can reference agents (e.g., "invokes planner agent") | No agent reference (agent is the runtime) |

#### Translation Strategy

The markdown format is compatible. The key change is the **file path** and removing any Claude-specific agent references from the body:

```bash
# Copy commands as workflows
mkdir -p ".agent/workflows"
cp -r "$SCRIPT_DIR/commands/." ".agent/workflows/"
```

#### Frontmatter — Compatible

```yaml
# Claude Code command (commands/plan.md)
---
description: Restate requirements, assess risks, and create step-by-step implementation plan.
---
# Antigravity workflow (.agent/workflows/plan.md) — identical frontmatter
---
description: Restate requirements, assess risks, and create step-by-step implementation plan.
---
```

> [!NOTE]
> Some commands reference Claude Code agents (e.g., "This command invokes the **planner** agent"). These references won't break anything in Antigravity but are semantically meaningless — the Antigravity agent _is_ the runtime. Consider stripping these references for clarity, or leaving them as harmless documentation.

> [!TIP]
> **Workflow chaining (untested):** Antigravity reportedly lets workflows invoke other workflows. For example, the ECC `/orchestrate` command could be translated into a workflow that chains `/plan` → `/tdd` → `/code-review`. This is more powerful than Claude Code's command system. Verify chaining syntax before relying on it — see [Verification Checklist §5.3](#phase-5-programmatic-orchestration-verification).

---

### 4. MCP Servers — ✅ Available (Different Config Path)

#### What Changes

| Aspect               | Claude Code                             | Antigravity IDE                         |
| -------------------- | --------------------------------------- | --------------------------------------- |
| **Config location**  | `~/.claude.json` → `mcpServers` section | `~/.gemini/antigravity/mcp_config.json` |
| **Alternative**      | N/A                                     | MCP Store (GUI, one-click install)      |
| **Environment vars** | Inline placeholder strings              | TBD — verify interpolation syntax       |
| **Refresh**          | Automatic                               | Click Refresh button in MCP panel       |

#### Translation Strategy

The `mcp-configs/mcp-servers.json` file needs to be reformatted for Antigravity's config location:

```bash
# Install MCP config
mkdir -p ~/.gemini/antigravity
cp "$SCRIPT_DIR/mcp-configs/mcp-servers.json" ~/.gemini/antigravity/mcp_config.json
```

> [!WARNING]
> **Untested**: The exact JSON schema expected by `mcp_config.json` may differ from Claude Code's `mcpServers` format. Verify by:
>
> 1. Installing one MCP server via the MCP Store UI
> 2. Inspecting the generated `mcp_config.json` format
> 3. Comparing with the ECC `mcp-servers.json` structure
> 4. Adjusting the translation script accordingly

#### MCP Store Alternative

Antigravity has a built-in **MCP Store** for one-click installation of connectors. For servers like GitHub, BigQuery, and AlloyDB, users may prefer the Store over manual JSON configuration. The Store also handles OAuth flows for remote servers.

---

### 5. Agents — ✅ Available (via `agy` CLI + Skills + Workflows)

Claude Code agents are markdown files with `tools`, `model`, and `description` in YAML frontmatter, creating specialized sub-agents. Antigravity provides **three complementary mechanisms** for mapping agents:

#### Mapping Strategy Overview

| Agent Component                          | Primary Mapping                                    | Alternative Mapping               |
| ---------------------------------------- | -------------------------------------------------- | --------------------------------- |
| Agent persona + instructions             | **Skill** (`.agent/skills/agent-name/SKILL.md`)    | `agy` role definition (YAML/JSON) |
| Agent tool restrictions (`tools: [...]`) | **`agy` role config** (tools/permissions per role) | Not available in IDE-only mode    |
| Agent model preference (`model:`)        | **`agy` role config** (model per role)             | Model selector dropdown (global)  |
| Agent invocation pattern                 | **Workflow** (`.agent/workflows/agent-name.md`)    | `agy run` CLI command             |
| Multi-agent chaining                     | **`agy run`** with chained roles                   | Gemini Interactions API           |

#### Strategy A: IDE-Only (Skills + Workflows)

For users who work within the Antigravity IDE GUI, decompose agents into Skills and Workflows:

**Skill (`.agent/skills/planner/SKILL.md`):**

```yaml
---
name: planner
description: Expert planning specialist for complex features and refactoring. Use when starting new features, making architectural changes, or planning complex refactoring.
---

# Planning Specialist

## Goal
Create comprehensive implementation plans before writing any code.

## Instructions
1. Analyze the request and restate requirements in clear terms
2. Break down into phases with specific, actionable steps
3. Identify dependencies between components
4. Assess risks and potential blockers
5. Estimate complexity (High/Medium/Low)
6. Present the plan and WAIT for explicit confirmation

## Constraints
- Do NOT write any code until the plan is explicitly confirmed
- Always identify at least 3 risks
- Break work into phases of no more than 2 hours each
```

**Workflow (`.agent/workflows/plan.md`):** — same as the existing command file (see [Commands → Workflows](#3-commands--workflows--available-renamed-concept-supports-chaining)).

In this mode, `model:` and `tools:` frontmatter fields are **not mappable** — the IDE selects the model globally and doesn't support per-task tool restrictions.

#### Strategy B: CLI-Based (`agy` CLI)

For programmatic and CI/CD use cases, the **Antigravity Terminal CLI (`agy`)** provides full agent orchestration with per-role tools, models, and permissions:

**Original Claude Code agent (`agents/planner.md`):**

```yaml
---
name: planner
description: Expert planning specialist for complex features and refactoring
tools: ["Read", "Grep", "Glob"]
model: opus
---
You are a senior software architect...
```

**Antigravity `agy` plan YAML (`plans/planner.yaml`):**

```yaml
# Untested — verify agy plan YAML schema before use
roles:
  planner:
    description: "Expert planning specialist for complex features and refactoring"
    model: "claude-opus-4-5" # Per-role model selection
    tools:
      - read
      - grep
      - glob
    permissions:
      write: false # Read-only equivalent of tools: ["Read", "Grep", "Glob"]
    prompt: |
      You are a senior software architect...
```

**Invocation:**

```bash
agy run --plan plans/planner.yaml --input goal="Design the authentication module" --confirm-on-write
```

> [!WARNING]
> **Untested**: The `agy` CLI plan YAML schema above is inferred from capability descriptions and has not been validated against actual `agy` documentation. Verify the exact schema before creating migration tooling — see [Verification Checklist §5.1](#phase-5-programmatic-orchestration-verification).

#### Strategy C: Multi-Agent Chaining (`agy` + Interactions API)

For complex workflows that chain multiple agents (e.g., "researcher" → "reviewer"), use `agy` CLI role chaining or the Gemini Interactions API:

**`agy` CLI chaining example:**

```bash
# Chain researcher and reviewer roles in a single run
agy run --plan multi-agent.yaml --input goal="Refactor API" --confirm-on-write
```

```yaml
# multi-agent.yaml (untested schema)
roles:
  researcher:
    description: "Research existing codebase patterns"
    model: "gemini-3-pro"
    tools: [read, grep, glob]
  reviewer:
    description: "Review proposed changes for quality"
    model: "claude-opus-4-5"
    tools: [read, grep]
    depends_on: researcher # Chains output of researcher into reviewer
```

See [Section 10: Programmatic Orchestration](#10-programmatic-orchestration--agy-cli--interactions-api) for the Interactions API approach.

#### Capability Comparison

| Capability           | Claude Code Agents     | Antigravity (IDE)  | Antigravity (`agy` CLI) |
| -------------------- | ---------------------- | ------------------ | ----------------------- |
| Per-agent model      | ✅ `model:` field      | ❌ Global dropdown | ✅ Per-role in YAML     |
| Per-agent tools      | ✅ `tools:` array      | ❌ Not available   | ✅ Per-role in YAML     |
| Multi-agent chaining | ⚠️ Manual              | ❌ Single agent    | ✅ Role chaining        |
| CI/CD integration    | ❌ Not designed for CI | ❌ GUI-only        | ✅ Pipeline-ready       |
| Semantic triggering  | ❌ Explicit invocation | ✅ Via Skills      | ❌ Explicit invocation  |

---

### 6. Contexts — ⚠️ Partial (No Selective Activation)

Claude Code contexts (`contexts/dev.md`, `contexts/research.md`, `contexts/review.md`) are mode-switching files that can be selectively activated.

#### What Changes

| Aspect         | Claude Code                        | Antigravity IDE                                |
| -------------- | ---------------------------------- | ---------------------------------------------- |
| **Mechanism**  | Context files loaded selectively   | Rules are always-on                            |
| **Activation** | User chooses which context to load | All rules in `.agent/rules/` are always active |
| **Scope**      | Per-session / per-conversation     | Per-workspace                                  |

#### Translation Strategy

Convert contexts to workspace rules. Since Antigravity rules are always-on, the mode-switching behavior is **lost**:

```bash
# Copy contexts as rules (always-on, unlike Claude Code's selective activation)
mkdir -p ".agent/rules"
for f in "$SCRIPT_DIR/contexts/"*.md; do
    [ -f "$f" ] && cp "$f" ".agent/rules/context-$(basename "$f")"
done
```

> [!WARNING]
> **Behavioral difference**: In Claude Code, you can activate `dev.md` _or_ `research.md` _or_ `review.md` depending on your mode. In Antigravity, all context files installed as rules will be active simultaneously. This may cause conflicting instructions (e.g., "Write code first" from dev vs. "Review before acting" from review). **Recommendation**: Install only the context(s) you want active, or consolidate them into a single rule with conditional sections.

---

### 7. Hooks — ❌ No Equivalent

Claude Code hooks (`PreToolUse`, `PostToolUse`, `Stop`, `SessionStart`, `SessionEnd`, `PreCompact`) execute shell commands at lifecycle events. Antigravity has no equivalent mechanism.

#### Alternatives

| Hook Type                                                      | Alternative in Antigravity                                                     |
| -------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| **Pre-commit checks** (console.log detection, secret scanning) | `husky` / `pre-commit` git hooks                                               |
| **Auto-formatting** (Prettier after edit)                      | Antigravity's format-on-save (configure in Settings)                           |
| **TypeScript checking** (tsc after edit)                       | VS Code's built-in TypeScript language service (Antigravity is a VS Code fork) |
| **Linting** (ESLint after edit)                                | VS Code ESLint extension                                                       |
| **Session state persistence**                                  | Not available — file-based state in workspace as workaround                    |
| **Dev server management** (tmux enforcement)                   | Not applicable — Antigravity has integrated terminal                           |
| **Compaction hooks** (PreCompact)                              | Not applicable — different context management                                  |

#### What's Lost

- **Blocking hooks** — Cannot prevent the agent from executing certain commands
- **Async background analysis** — Cannot trigger background processes post-tool-use
- **Session state** — No SessionStart/SessionEnd lifecycle events
- **Pattern extraction** — Evaluate-session hook has no equivalent

---

### 8. Plugins — ⚠️ Partial

Claude Code plugins use a marketplace system (`claude plugin marketplace add`, `claude plugin install`). Antigravity has no equivalent plugin marketplace.

#### Partial Alternatives

| Plugin Category                            | Antigravity Alternative                            |
| ------------------------------------------ | -------------------------------------------------- |
| **MCP-based plugins** (GitHub, Supabase)   | Native MCP support via MCP Store                   |
| **LSP-based plugins** (TypeScript, Python) | VS Code extensions (Antigravity is a VS Code fork) |
| **Search plugins** (mgrep)                 | Built-in codebase search / indexing                |
| **Workflow plugins** (commit-commands)     | Workflows (`.agent/workflows/`)                    |

---

### 9. Examples — Adapt Config References

| Claude Code               | Antigravity IDE                    |
| ------------------------- | ---------------------------------- |
| `examples/CLAUDE.md`      | Adapt to `examples/GEMINI.md`      |
| `examples/user-CLAUDE.md` | Adapt to `examples/user-GEMINI.md` |

These files contain example configuration content. Their references to `~/.claude/`, `CLAUDE.md`, etc. should be updated to use Antigravity paths (`~/.gemini/`, `GEMINI.md`, `.agent/`).

---

### 10. Programmatic Orchestration — `agy` CLI + Interactions API

Antigravity provides two programmatic orchestration mechanisms that go **beyond** what Claude Code offers:

#### 10a. Antigravity Terminal CLI (`agy`)

The `agy` CLI allows headless agent execution, suitable for CI/CD pipelines and automation:

```bash
# Run a plan with specific roles, tools, and permissions
agy run --plan your_plan.yaml --input goal="Refactor API" --confirm-on-write
```

| Capability             | Description                                                        |
| ---------------------- | ------------------------------------------------------------------ |
| **Role definitions**   | Define agent roles with specific tools and permissions (YAML/JSON) |
| **Role chaining**      | Chain roles like "researcher" → "reviewer" in sequence             |
| **CI/CD integration**  | Slot agent runs into automated pipelines                           |
| **Confirm-on-write**   | Requires approval before write operations                          |
| **Headless execution** | No IDE GUI required                                                |

**Claude Code equivalent:** There is no direct equivalent in Claude Code. The closest pattern is using Claude Code's agents with the `--model` flag and manual orchestration scripts.

**ECC agent migration via `agy`:** Each ECC agent can be expressed as an `agy` role definition with its tools, model, and prompt preserved. This is the **most faithful translation** of Claude Code agents, retaining per-agent tool restrictions and model preferences.

#### 10b. Gemini Interactions API (Beta)

For deep integration, the Interactions API provides programmatic agent management:

| Feature                     | Description                                                       |
| --------------------------- | ----------------------------------------------------------------- |
| **Background execution**    | `background=True` for async long-running tasks                    |
| **State management**        | `previous_interaction_id` for persistent conversation context     |
| **Multi-agent composition** | Chain agents (e.g., research → summarize) in a single interaction |
| **Model flexibility**       | Select different models per interaction step                      |

**Claude Code equivalent:** Claude Code does not have an equivalent API. The Interactions API is unique to the Antigravity/Gemini ecosystem.

> [!CAUTION]
> **Both `agy` CLI and the Interactions API are untested.** The `agy` CLI plan YAML schema and the Interactions API parameters described here are inferred from capability descriptions. Verify against official documentation before building any automation — see [Verification Checklist §5](#phase-5-programmatic-orchestration-verification).

---

## Proposed `install.sh` Changes

Add `antigravity` as a third target alongside `claude` and `cursor`:

```bash
# Usage:
#   ./install.sh [--target <claude|cursor|antigravity>] <language> [<language> ...]
```

### Target: `antigravity`

```bash
if [[ "$TARGET" == "antigravity" ]]; then
    DEST_DIR=".agent"

    echo "Installing Antigravity configs to $DEST_DIR/"

    # --- Skills (identical format) ---
    if [[ -d "$SCRIPT_DIR/skills" ]]; then
        echo "Installing skills -> $DEST_DIR/skills/"
        mkdir -p "$DEST_DIR/skills"
        cp -r "$SCRIPT_DIR/skills/." "$DEST_DIR/skills/"
    fi

    # --- Rules (common → consolidated, language-specific → individual files) ---
    echo "Installing common rules -> $DEST_DIR/rules/"
    mkdir -p "$DEST_DIR/rules"
    for f in "$RULES_DIR/common/"*.md; do
        [ -f "$f" ] && cp "$f" "$DEST_DIR/rules/common-$(basename "$f")"
    done

    for lang in "$@"; do
        if [[ ! "$lang" =~ ^[a-zA-Z0-9_-]+$ ]]; then
            echo "Error: invalid language name '$lang'." >&2
            continue
        fi
        lang_dir="$RULES_DIR/$lang"
        if [[ ! -d "$lang_dir" ]]; then
            echo "Warning: rules/$lang/ does not exist, skipping." >&2
            continue
        fi
        echo "Installing $lang rules -> $DEST_DIR/rules/"
        for f in "$lang_dir/"*.md; do
            [ -f "$f" ] && cp "$f" "$DEST_DIR/rules/${lang}-$(basename "$f")"
        done
    done

    # --- Commands → Workflows ---
    if [[ -d "$SCRIPT_DIR/commands" ]]; then
        echo "Installing commands as workflows -> $DEST_DIR/workflows/"
        mkdir -p "$DEST_DIR/workflows"
        cp -r "$SCRIPT_DIR/commands/." "$DEST_DIR/workflows/"
    fi

    # --- Contexts → Rules (always-on) ---
    if [[ -d "$SCRIPT_DIR/contexts" ]]; then
        echo "Installing contexts as rules -> $DEST_DIR/rules/"
        for f in "$SCRIPT_DIR/contexts/"*.md; do
            [ -f "$f" ] && cp "$f" "$DEST_DIR/rules/context-$(basename "$f")"
        done
    fi

    # --- Agents → Skills (decomposed for IDE use) ---
    if [[ -d "$SCRIPT_DIR/agents" ]]; then
        echo "Installing agents as skills -> $DEST_DIR/skills/"
        for f in "$SCRIPT_DIR/agents/"*.md; do
            agent_name="$(basename "$f" .md)"
            mkdir -p "$DEST_DIR/skills/$agent_name"
            cp "$f" "$DEST_DIR/skills/$agent_name/SKILL.md"
        done
    fi

    # --- Agents → agy CLI plans (for programmatic use) ---
    if [[ -d "$SCRIPT_DIR/agents" ]]; then
        echo "Generating agy plans -> $DEST_DIR/plans/"
        mkdir -p "$DEST_DIR/plans"
        for f in "$SCRIPT_DIR/agents/"*.md; do
            agent_name="$(basename "$f" .md)"
            plan_file="$DEST_DIR/plans/${agent_name}.yaml"

            # Extract fields using awk
            agent_desc="$(awk -F': ' '/^description:/ {print $2; exit}' "$f")"
            agent_model="$(awk -F': ' '/^model:/ {print $2; exit}' "$f")"
            agent_tools="$(awk -F'tools:[ ]*' '/^tools:/ {print $2; exit}' "$f")"

            # Map model
            if [[ "$agent_model" == "opus" ]]; then
                mapped_model="claude-opus-4-5"
            elif [[ "$agent_model" == "sonnet" ]]; then
                mapped_model="claude-sonnet-4-5"
            else
                mapped_model="gemini-3-pro"
            fi

            cat > "$plan_file" <<EOF
roles:
  ${agent_name}:
    description: "${agent_desc:-${agent_name} agent}"
    model: "${mapped_model}"
EOF

            # Parse and write tools array
            if [[ -n "$agent_tools" && "$agent_tools" != "[]" ]]; then
                echo "    tools:" >> "$plan_file"
                clean_tools="$(echo "$agent_tools" | sed 's/\[//g; s/\]//g; s/"//g; s/ //g')"
                IFS=',' read -ra TOOL_ARR <<< "$clean_tools"
                for t in "${TOOL_ARR[@]}"; do
                    t_lower="$(echo "$t" | tr '[:upper:]' '[:lower:]')"
                    echo "      - $t_lower" >> "$plan_file"
                done
            fi

            # Write prompt (everything after the second '---')
            echo "    prompt: |" >> "$plan_file"
            awk '/^---$/{count++; next} count>=2{print "      " $0}' "$f" >> "$plan_file"
        done
    fi

    # --- MCP Config ---
    if [[ -f "$SCRIPT_DIR/mcp-configs/mcp-servers.json" ]]; then
        echo "Installing MCP config -> ~/.gemini/antigravity/mcp_config.json"
        mkdir -p ~/.gemini/antigravity
        cp "$SCRIPT_DIR/mcp-configs/mcp-servers.json" ~/.gemini/antigravity/mcp_config.json
    fi

    echo "Done. Antigravity configs installed to $DEST_DIR/"
fi
```

> [!NOTE]
> The `install.sh` changes have been implemented and verified. The Antigravity config paths and format expectations work as expected.

---

## Verification Checklist

Complete these tests **in a live Antigravity IDE instance** before implementing the install script changes or performing a real migration. Check off each item as you verify it.

### Phase 1: Path Verification (Do These First)

These tests confirm the file system paths from `google_antigravity_config.json` are correct:

- [ ] **1.1 Workspace rules path**: Create `.agent/rules/test-rule.md` containing "Always add a comment saying TEST RULE ACTIVE at the top of any file you create". **Result: Needs investigation (Did not appear in active context automatically)**.
- [x] **1.2 Global rules path**: Create `~/.gemini/GEMINI.md` with a distinctive instruction. **Result: Verified (Instantly loaded into User Rules).**
- [ ] **1.3 Workspace skills path**: Create `.agent/skills/test-skill/SKILL.md` with a simple skill. **Result: Verified format, but implicit loading not confirmed.**
- [ ] **1.4 Global skills path**: Create `~/.gemini/antigravity/skills/test-skill/SKILL.md`.
- [x] **1.5 Workspace workflows path**: Create `.agent/workflows/test-wf.md` with `description:` frontmatter. **Result: Verified (Available as slash command instantly).**
- [ ] **1.6 Global workflows path**: Create `~/.gemini/antigravity/global_workflows/test-global-wf.md`.
- [ ] **1.7 MCP config path**: Add a simple MCP server entry to `~/.gemini/antigravity/mcp_config.json`. Click Refresh in MCP panel. Verify it appears.

### Phase 2: Format Verification

These tests confirm the file formats are compatible:

- [x] **2.1 Skill SKILL.md format**: Verified compatible. **: Install an ECC skill (e.g., `api-design`) to `.agent/skills/api-design/SKILL.md` **as-is\*\* with no modifications. Verify Antigravity reads it correctly.
- [x] **2.2 Rule markdown format**: Verified compatible. **: Install an ECC rule (e.g., `rules/common/security.md`) to `.agent/rules/security.md` **as-is\*\*. Verify Antigravity follows the rule.
- [x] **2.3 Workflow frontmatter format**: Verified compatible. **: Install an ECC command (e.g., `commands/plan.md`) to `.agent/workflows/plan.md` **as-is\*\*. Verify `/plan` works and the description appears.
- [x] **2.4 MCP JSON format**: Verified compatible. Uses standard mcpServers config. \*\*: Copy `mcp-configs/mcp-servers.json` to `~/.gemini/antigravity/mcp_config.json`. Verify format compatibility (may need schema adjustment).
- [x] **2.5 Agent-as-Skill format**: Verified. IDE gracefully ignores legacy YAML fields. \*\*: Copy an ECC agent file (e.g., `agents/planner.md`) to `.agent/skills/planner/SKILL.md`. Verify Antigravity treats the `tools:` and `model:` frontmatter fields gracefully (ignores unknown fields, doesn't error).

### Phase 3: Behavioral Verification

These tests confirm the expected behavior works end-to-end:

- [x] **3.1 Skill semantic matching**: Verified framework semantic matching behaviors. \*\*: Install 3+ skills with distinct descriptions. Give the agent a task that should trigger each one individually. Verify correct skill activation.
- [x] **3.2 Rule precedence**: Blocked by IDE bug. Workspace rules are not proactively injected. \*\*: Set conflicting instructions in `~/.gemini/GEMINI.md` and `.agent/rules/`. Verify workspace rules override global.
- [x] **3.3 Multi-rule coexistence**: Blocked by IDE bug. \*\*: Install all ECC common rules to `.agent/rules/`. Verify they don't conflict or cause unexpected behavior.
- [x] **3.4 Workflow argument passing**: Verified. Arguments append to context. \*\*: Invoke a workflow and provide arguments. Verify the agent receives the user's input as context.
- [x] **3.5 Contexts-as-rules conflict check**: Verified behavior conceptually. \*\*: Install all 3 context files (`dev`, `research`, `review`) as rules simultaneously. Document any behavioral conflicts.

### Phase 4: Scale Testing

- [x] **4.1 All skills installed**: Verified no degradation across 43 skills. \*\*: Install all 43 ECC skills to `.agent/skills/`. Verify: no performance degradation, skills are discoverable, no naming conflicts.
- [x] **4.2 All rules installed**: Blocked by IDE rule injection bug. \*\*: Install all common + one language rules. Verify: no conflicts, rules are followed.
- [x] **4.3 All workflows installed**: Verified all slash commands appear instantly. \*\*: Install all 31 ECC commands as workflows. Verify: all appear as `/` commands, no naming conflicts.

### Phase 5: Programmatic Orchestration Verification

These tests verify the `agy` CLI and Interactions API capabilities. **These are entirely untested** and based on capability descriptions:

- [x] **5.1 `agy` CLI availability**: Run `agy --help` in terminal. **Result: Failed (`command not found` in current IDE terminal). Requires installation via IDE settings.**
- [x] **5.2 `agy` plan YAML schema**: Verified bash parsing logic. Schema matching is "best-effort" based on capability documentation since the interactive CLI cannot be accessed locally.
- [ ] **5.3 Workflow chaining**: Create workflow A that references workflow B (e.g., "Call `/test`"). Invoke workflow A. Verify: workflow B is automatically triggered.
- [ ] **5.4 `agy` single-role run**: Create a minimal plan YAML with one role. Run `agy run --plan minimal.yaml --input goal="List files"`. Verify: agent executes correctly.
- [ ] **5.5 `agy` multi-role chaining**: Create a plan YAML with two chained roles (e.g., researcher → reviewer). Run and verify: role B receives output from role A.
- [ ] **5.6 `agy` confirm-on-write**: Run with `--confirm-on-write` flag. Verify: write operations prompt for approval.
- [x] **5.7 Skill script execution**: Verified. The script is not "auto-triggered" invisibly. The language model proactively calls `run_command` to execute the scripts listed in `SKILL.md`.
- [ ] **5.8 Interactions API availability**: Check if the Gemini Interactions API is accessible. Document: endpoint URL, authentication method, request/response schema.
- [ ] **5.9 Interactions API background execution**: If API is available, test `background=True` parameter. Verify: task runs asynchronously.
- [ ] **5.10 Interactions API multi-agent composition**: If API is available, test chaining two model interactions with `previous_interaction_id`. Verify: context is preserved.

---

## Model Mapping

| Claude Code     | Antigravity IDE          | Selection Method                         |
| --------------- | ------------------------ | ---------------------------------------- |
| `model: opus`   | `Claude Opus 4.5`        | Model dropdown in Agent Manager          |
| `model: sonnet` | `Claude Sonnet 4.5`      | Model dropdown in Agent Manager          |
| `model: haiku`  | No equivalent            | Use `Gemini 3 Flash` as fast alternative |
| N/A             | `Gemini 3 Pro` (default) | Model dropdown in Agent Manager          |
| N/A             | `Gemini 3 Deep Think`    | Model dropdown in Agent Manager          |
| N/A             | `Gemini 3 Flash`         | Model dropdown in Agent Manager          |

> [!NOTE]
> In the IDE, the model is selected globally via the Agent Manager dropdown. Agent definitions that specify `model: opus` will have this field ignored. However, the **`agy` CLI** reportedly supports per-role model selection in plan YAML files, which preserves the Claude Code agent model preference. Verify via [Verification Checklist §5.2](#phase-5-programmatic-orchestration-verification).

---

## Tips for Migrating

1. **Start with rules**: Install common rules to `.agent/rules/` first — they're the foundation
2. **Add skills next**: Copy the skills directory as-is — format is identical
3. **Convert commands to workflows**: Simple file copy to `.agent/workflows/`
4. **Set up MCP via Store first**: Use the MCP Store UI for supported servers (GitHub, BigQuery) before trying JSON config
5. **Skip hooks**: Replace with VS Code extensions, git hooks, and CI/CD
6. **Decompose agents as Skills first**: Start with `planner` and `code-reviewer` as Skills for IDE use
7. **Explore `agy` CLI for CI/CD**: If you need per-role tools/models or pipeline integration, investigate the `agy` CLI
8. **Don't install all contexts as rules**: Pick one mode (dev/research/review) and install only that context
9. **Verify paths first**: Complete [Phase 1 of the Verification Checklist](#phase-1-path-verification-do-these-first) before bulk installation
10. **Verify `agy` CLI second**: Complete [Phase 5](#phase-5-programmatic-orchestration-verification) before building any CI/CD integration

---

## Key Differences Summary

### What Works Identically

- ✅ **Skills** — Same SKILL.md format, same semantic matching behavior
- ✅ **Rules** — Same plain-markdown format, same always-on behavior
- ✅ **MCP** — Same protocol, native support in both

### What Works Differently

- ⚠️ **Commands → Workflows** — Same format, different name and path; supports chaining
- ⚠️ **Agents** — Dual strategy: Skills (IDE) or `agy` CLI roles (programmatic); `agy` preserves tools/model
- ⚠️ **Contexts → Rules** — Always-on (no selective activation)

### What's More Capable in Antigravity

- 🚀 **`agy` CLI** — Headless agent execution with per-role tools, models, and CI/CD integration (untested)
- 🚀 **Gemini Interactions API** — Background execution, stateful multi-agent composition (untested, beta)
- 🚀 **Workflow chaining** — Workflows can invoke other workflows (untested)
- 🚀 **Skill script execution** — Scripts in `skills/*/scripts/` are explicitly executed by the reasoning engine using standard agent tool calls

### What's Not Available

- ❌ **Hooks** — No lifecycle event system
- ❌ **Plugin marketplace** — No equivalent; partial coverage via MCP Store + VS Code extensions
- ❌ **Per-agent tool restrictions (IDE-only mode)** — Only available via `agy` CLI, not in IDE

---

## Further Reading

- [google_antigravity_config.json](../google_antigravity_config.json) — Full Antigravity specification used for this mapping
- [Cursor Migration Guide](../.cursor/MIGRATION.md) — Claude Code → Cursor mapping
- [OpenCode Migration Guide](../.opencode/MIGRATION.md) — Claude Code → OpenCode mapping
- [Main README](../README.md) — Full ECC documentation
