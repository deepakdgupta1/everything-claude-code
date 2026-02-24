#!/usr/bin/env bash
# install.sh — Install ECC assets for Claude/Cursor/Codex/Antigravity/Amp/Kilo targets.
#
# Usage:
#   ./install.sh [--target <claude|cursor|antigravity|codex|amp|kilo>] [<language> ...]
#
# Examples:
#   ./install.sh typescript
#   ./install.sh typescript python golang
#   ./install.sh --target cursor typescript
#   ./install.sh --target cursor typescript python golang
#   ./install.sh --target codex
#   ./install.sh --target amp typescript python golang
#   ./install.sh --target amp                          # all languages
#   ./install.sh --target kilo                         # all languages + skills/workflows
#
# Targets:
#   claude      (default) — Install rules to ~/.claude/rules/
#   cursor      — Install rules, agents, skills, commands, and MCP to ./.cursor/
#   antigravity — Install rules, skills, workflows, and MCP for Antigravity IDE
#   codex       — Install all ECC skills + Codex global AGENTS setup (+ VS Code binding)
#   amp         — Install skills, agents, commands, rules, MCP, and AGENTS.md for Amp CLI & VS Code
#   kilo        — Install ECC into Kilo workspace structure (.kilocode + AGENTS.md)
#
# This script copies rules into the target directory keeping the common/ and
# language-specific subdirectories intact so that:
#   1. Files with the same name in common/ and <language>/ don't overwrite
#      each other.
#   2. Relative references (e.g. ../common/coding-style.md) remain valid.

set -euo pipefail

# Resolve symlinks — needed when invoked as `ecc-install` via npm/bun bin symlink
SCRIPT_PATH="$0"
while [ -L "$SCRIPT_PATH" ]; do
    link_dir="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
    SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
    # Resolve relative symlinks
    [[ "$SCRIPT_PATH" != /* ]] && SCRIPT_PATH="$link_dir/$SCRIPT_PATH"
done
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
RULES_DIR="$SCRIPT_DIR/rules"

upsert_toml_key() {
    local file="$1"
    local key="$2"
    local value="$3"
    local tmp_file

    mkdir -p "$(dirname "$file")"
    [[ -f "$file" ]] || touch "$file"

    tmp_file="$(mktemp)"
    awk -v key="$key" -v value="$value" '
        BEGIN { replaced = 0 }
        {
            if ($0 ~ "^[[:space:]]*" key "[[:space:]]*=") {
                if (!replaced) {
                    print key " = " value
                    replaced = 1
                }
                next
            }
            print
        }
        END {
            if (!replaced) {
                print key " = " value
            }
        }
    ' "$file" > "$tmp_file"

    mv "$tmp_file" "$file"
}

write_codex_agents_file() {
    local agents_file="$1"
    local skills_dir="$2"
    local ecc_dir="$3"
    local tmp_file backup_file

    tmp_file="$(mktemp)"
    cat > "$tmp_file" <<EOF
# AGENTS.md

Global instructions for using Everything Claude Code (ECC) with OpenAI Codex.

## Installed ECC Assets
- Skills: ${skills_dir}/
- Agent source prompts: ${ecc_dir}/agents/
- Workflow command playbooks: ${ecc_dir}/commands/
- Context docs: ${ecc_dir}/contexts/
- Rules reference: ${ecc_dir}/rules/
- Hooks/scripts reference: ${ecc_dir}/hooks/, ${ecc_dir}/scripts/
- MCP config examples: ${ecc_dir}/mcp-configs/

## Working Rules
1. Use applicable skills from ${skills_dir}/ first.
2. Treat ${ecc_dir}/commands as reusable workflow blueprints.
3. Use ${ecc_dir}/agents for role-specific reviews/planning when needed.
4. If a repository has AGENTS.md or CLAUDE.md, prefer repository-local instructions over this global file.
5. Keep changes minimal, testable, and aligned with repository conventions.
EOF

    mkdir -p "$(dirname "$agents_file")"
    if [[ -f "$agents_file" ]] && ! cmp -s "$tmp_file" "$agents_file"; then
        backup_file="${agents_file}.bak.$(date +%Y%m%d-%H%M%S)"
        cp "$agents_file" "$backup_file"
        echo "Backed up existing AGENTS.md -> $backup_file"
    fi

    mv "$tmp_file" "$agents_file"
}

write_kilo_agents_file() {
    local agents_file="$1"
    local skills_dir="$2"
    local rules_dir="$3"
    local workflows_dir="$4"
    local tmp_file backup_file

    tmp_file="$(mktemp)"
    cat > "$tmp_file" <<EOF
# AGENTS.md

Project instructions for using Everything Claude Code (ECC) with Kilo Code.

## Installed ECC Assets
- Skills: ${skills_dir}/
- Rules: ${rules_dir}/
- Workflows: ${workflows_dir}/

## Usage Guidance
1. Use relevant skills first before ad-hoc prompting.
2. Use workflows for repeatable multi-step tasks.
3. Follow .kilocode/rules guidance for coding style, testing, security, and workflow standards.
4. Keep changes minimal, testable, and aligned with existing repository conventions.
5. Ask before potentially destructive operations.
EOF

    mkdir -p "$(dirname "$agents_file")"
    if [[ -f "$agents_file" ]] && ! cmp -s "$tmp_file" "$agents_file"; then
        backup_file="${agents_file}.bak.$(date +%Y%m%d-%H%M%S)"
        cp "$agents_file" "$backup_file"
        echo "Backed up existing AGENTS.md -> $backup_file"
    fi

    mv "$tmp_file" "$agents_file"
}

set_vscode_codex_cli_path() {
    local settings_file="$1"
    local codex_bin="$2"

    mkdir -p "$(dirname "$settings_file")"

    if [[ ! -f "$settings_file" ]]; then
        cat > "$settings_file" <<EOF
{
  "chatgpt.codexCliPath": "$codex_bin"
}
EOF
        echo "Created VS Code settings -> $settings_file"
        return 0
    fi

    if command -v python3 >/dev/null 2>&1; then
        if python3 - "$settings_file" "$codex_bin" <<'PY'
import json
import sys

settings_file, codex_bin = sys.argv[1], sys.argv[2]
with open(settings_file, "r", encoding="utf-8") as f:
    data = json.load(f)
if not isinstance(data, dict):
    raise SystemExit(2)
data["chatgpt.codexCliPath"] = codex_bin
with open(settings_file, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PY
        then
            echo "Updated VS Code setting chatgpt.codexCliPath -> $settings_file"
            return 0
        fi
    fi

    echo "Warning: could not parse $settings_file as JSON (possibly JSONC)."
    echo "         Set chatgpt.codexCliPath manually to: $codex_bin"
    return 0
}

# --- Parse --target flag ---
TARGET="claude"
if [[ "${1:-}" == "--target" ]]; then
    if [[ -z "${2:-}" ]]; then
        echo "Error: --target requires a value (claude, cursor, antigravity, codex, amp, or kilo)" >&2
        exit 1
    fi
    TARGET="$2"
    shift 2
fi

if [[ "$TARGET" != "claude" && "$TARGET" != "cursor" && "$TARGET" != "antigravity" && "$TARGET" != "codex" && "$TARGET" != "amp" && "$TARGET" != "kilo" ]]; then
    echo "Error: unknown target '$TARGET'. Must be 'claude', 'cursor', 'antigravity', 'codex', 'amp', or 'kilo'." >&2
    exit 1
fi

# --- Usage ---
if [[ "$TARGET" != "codex" && "$TARGET" != "amp" && "$TARGET" != "kilo" && $# -eq 0 ]]; then
    echo "Usage: $0 [--target <claude|cursor|antigravity|codex|amp|kilo>] [<language> ...]"
    echo ""
    echo "Targets:"
    echo "  claude      (default) — Install rules to ~/.claude/rules/"
    echo "  cursor      — Install rules, agents, skills, commands, and MCP to ./.cursor/"
    echo "  antigravity — Install rules, skills, workflows, and MCP for Antigravity IDE"
    echo "  codex       — Install all ECC skills + Codex global AGENTS setup (+ VS Code binding)"
    echo "  amp         — Install skills, agents, commands, rules, MCP, and AGENTS.md for Amp CLI & VS Code"
    echo "  kilo        — Install ECC into Kilo workspace structure (.kilocode + AGENTS.md)"
    echo ""
    echo "Available languages:"
    for dir in "$RULES_DIR"/*/; do
        name="$(basename "$dir")"
        [[ "$name" == "common" ]] && continue
        echo "  - $name"
    done
    exit 1
fi

# --- Claude target (existing behavior) ---
if [[ "$TARGET" == "claude" ]]; then
    DEST_DIR="${CLAUDE_RULES_DIR:-$HOME/.claude/rules}"

    # Warn if destination already exists (user may have local customizations)
    if [[ -d "$DEST_DIR" ]] && [[ "$(ls -A "$DEST_DIR" 2>/dev/null)" ]]; then
        echo "Note: $DEST_DIR/ already exists. Existing files will be overwritten."
        echo "      Back up any local customizations before proceeding."
    fi

    # Always install common rules
    echo "Installing common rules -> $DEST_DIR/common/"
    mkdir -p "$DEST_DIR/common"
    cp -r "$RULES_DIR/common/." "$DEST_DIR/common/"

    # Install each requested language
    for lang in "$@"; do
        # Validate language name to prevent path traversal
        if [[ ! "$lang" =~ ^[a-zA-Z0-9_-]+$ ]]; then
            echo "Error: invalid language name '$lang'. Only alphanumeric, dash, and underscore allowed." >&2
            continue
        fi
        lang_dir="$RULES_DIR/$lang"
        if [[ ! -d "$lang_dir" ]]; then
            echo "Warning: rules/$lang/ does not exist, skipping." >&2
            continue
        fi
        echo "Installing $lang rules -> $DEST_DIR/$lang/"
        mkdir -p "$DEST_DIR/$lang"
        cp -r "$lang_dir/." "$DEST_DIR/$lang/"
    done

    echo "Done. Rules installed to $DEST_DIR/"
fi

# --- Cursor target ---
if [[ "$TARGET" == "cursor" ]]; then
    DEST_DIR=".cursor"
    CURSOR_SRC="$SCRIPT_DIR/.cursor"

    echo "Installing Cursor configs to $DEST_DIR/"

    # --- Rules ---
    echo "Installing common rules -> $DEST_DIR/rules/"
    mkdir -p "$DEST_DIR/rules"
    # Copy common rules (flattened names like common-coding-style.md)
    if [[ -d "$CURSOR_SRC/rules" ]]; then
        for f in "$CURSOR_SRC/rules"/common-*.md; do
            [[ -f "$f" ]] && cp "$f" "$DEST_DIR/rules/"
        done
    fi

    # Install language-specific rules
    for lang in "$@"; do
        # Validate language name to prevent path traversal
        if [[ ! "$lang" =~ ^[a-zA-Z0-9_-]+$ ]]; then
            echo "Error: invalid language name '$lang'. Only alphanumeric, dash, and underscore allowed." >&2
            continue
        fi
        if [[ -d "$CURSOR_SRC/rules" ]]; then
            found=false
            for f in "$CURSOR_SRC/rules"/${lang}-*.md; do
                if [[ -f "$f" ]]; then
                    cp "$f" "$DEST_DIR/rules/"
                    found=true
                fi
            done
            if $found; then
                echo "Installing $lang rules -> $DEST_DIR/rules/"
            else
                echo "Warning: no Cursor rules for '$lang' found, skipping." >&2
            fi
        fi
    done

    # --- Agents ---
    if [[ -d "$CURSOR_SRC/agents" ]]; then
        echo "Installing agents -> $DEST_DIR/agents/"
        mkdir -p "$DEST_DIR/agents"
        cp -r "$CURSOR_SRC/agents/." "$DEST_DIR/agents/"
    fi

    # --- Skills ---
    if [[ -d "$CURSOR_SRC/skills" ]]; then
        echo "Installing skills -> $DEST_DIR/skills/"
        mkdir -p "$DEST_DIR/skills"
        cp -r "$CURSOR_SRC/skills/." "$DEST_DIR/skills/"
    fi

    # --- Commands ---
    if [[ -d "$CURSOR_SRC/commands" ]]; then
        echo "Installing commands -> $DEST_DIR/commands/"
        mkdir -p "$DEST_DIR/commands"
        cp -r "$CURSOR_SRC/commands/." "$DEST_DIR/commands/"
    fi

    # --- MCP Config ---
    if [[ -f "$CURSOR_SRC/mcp.json" ]]; then
        echo "Installing MCP config -> $DEST_DIR/mcp.json"
        cp "$CURSOR_SRC/mcp.json" "$DEST_DIR/mcp.json"
    fi

    echo "Done. Cursor configs installed to $DEST_DIR/"
fi

# --- Codex target ---
if [[ "$TARGET" == "codex" ]]; then
    DEST_DIR="${CODEX_AGENTS_DIR:-$HOME/.agents}"
    CODEX_CONFIG_FILE="${CODEX_CONFIG_FILE:-$HOME/.codex/config.toml}"
    VSCODE_SETTINGS_FILE="${VSCODE_SETTINGS_FILE:-$HOME/.config/Code/User/settings.json}"
    SKILLS_DEST="$DEST_DIR/skills"
    ECC_DEST="$DEST_DIR/ecc"
    AGENTS_FILE="$DEST_DIR/AGENTS.md"

    if [[ $# -gt 0 ]]; then
        echo "Note: language arguments are ignored for --target codex."
    fi

    echo "Installing Codex configs to $DEST_DIR/"

    if [[ -d "$SKILLS_DEST" ]] && [[ "$(ls -A "$SKILLS_DEST" 2>/dev/null)" ]]; then
        echo "Note: $SKILLS_DEST/ already exists. Existing files may be overwritten."
        echo "      Back up any local customizations before proceeding."
    fi

    # --- Skills ---
    if [[ -d "$SCRIPT_DIR/skills" ]]; then
        echo "Installing skills -> $SKILLS_DEST/"
        mkdir -p "$SKILLS_DEST"
        cp -r "$SCRIPT_DIR/skills/." "$SKILLS_DEST/"
    fi

    # --- Agents -> Skills ---
    if [[ -d "$SCRIPT_DIR/agents" ]]; then
        echo "Installing agents as skills -> $SKILLS_DEST/"
        for f in "$SCRIPT_DIR/agents/"*.md; do
            [[ -f "$f" ]] || continue
            agent_name="$(basename "$f" .md)"
            mkdir -p "$SKILLS_DEST/$agent_name"
            cp "$f" "$SKILLS_DEST/$agent_name/SKILL.md"
        done
    fi

    # --- ECC reference assets ---
    echo "Installing reference assets -> $ECC_DEST/"
    mkdir -p "$ECC_DEST"
    for component in agents commands contexts hooks mcp-configs rules scripts; do
        if [[ -e "$SCRIPT_DIR/$component" ]]; then
            mkdir -p "$ECC_DEST/$component"
            cp -r "$SCRIPT_DIR/$component/." "$ECC_DEST/$component/"
        fi
    done

    # --- Global AGENTS.md ---
    echo "Writing global AGENTS instructions -> $AGENTS_FILE"
    write_codex_agents_file "$AGENTS_FILE" "$SKILLS_DEST" "$ECC_DEST"

    # --- Codex config.toml wiring ---
    echo "Configuring Codex CLI -> $CODEX_CONFIG_FILE"
    upsert_toml_key "$CODEX_CONFIG_FILE" "model_instructions_file" "\"$AGENTS_FILE\""
    upsert_toml_key "$CODEX_CONFIG_FILE" "project_doc_fallback_filenames" "[\"AGENTS.md\", \"CLAUDE.md\"]"

    # --- VS Code extension binding ---
    if command -v codex >/dev/null 2>&1; then
        CODEX_BIN="$(command -v codex)"
    else
        CODEX_BIN="codex"
        echo "Warning: codex binary not found in PATH; setting VS Code path to 'codex'."
    fi
    set_vscode_codex_cli_path "$VSCODE_SETTINGS_FILE" "$CODEX_BIN"

    echo "Done. Codex configs installed to $DEST_DIR/"
fi

# --- Amp target ---
if [[ "$TARGET" == "amp" ]]; then
    AMP_SKILLS_DIR="${AMP_SKILLS_DIR:-$HOME/.config/amp/skills}"
    AMP_SETTINGS_FILE="${AMP_SETTINGS_FILE:-$HOME/.config/amp/settings.json}"
    AMP_AGENTS_FILE="${AMP_AGENTS_FILE:-$HOME/.config/amp/AGENTS.md}"
    RULES_DEST="${CLAUDE_RULES_DIR:-$HOME/.claude/rules}"

    # If no languages specified, install all available
    if [[ $# -eq 0 ]]; then
        set -- $(for dir in "$RULES_DIR"/*/; do
            name="$(basename "$dir")"
            [[ "$name" != "common" ]] && echo "$name"
        done)
        echo "No languages specified — installing all: $*"
    fi

    echo ""
    echo "Installing ECC for Amp CLI & VS Code Extension"
    echo "================================================"
    echo ""

    # ── 1. Rules → ~/.claude/rules/ ──
    echo "[1/6] Installing rules -> $RULES_DEST/"
    if [[ -d "$RULES_DEST" ]] && [[ "$(ls -A "$RULES_DEST" 2>/dev/null)" ]]; then
        echo "  Note: $RULES_DEST/ already exists. Existing files will be overwritten."
    fi
    mkdir -p "$RULES_DEST/common"
    cp -r "$RULES_DIR/common/." "$RULES_DEST/common/"
    rules_count=0
    for f in "$RULES_DIR/common/"*.md; do [ -f "$f" ] && rules_count=$((rules_count + 1)); done

    for lang in "$@"; do
        if [[ ! "$lang" =~ ^[a-zA-Z0-9_-]+$ ]]; then
            echo "  Error: invalid language name '$lang'. Skipping." >&2
            continue
        fi
        lang_dir="$RULES_DIR/$lang"
        if [[ ! -d "$lang_dir" ]]; then
            echo "  Warning: rules/$lang/ does not exist, skipping." >&2
            continue
        fi
        mkdir -p "$RULES_DEST/$lang"
        cp -r "$lang_dir/." "$RULES_DEST/$lang/"
        for f in "$lang_dir/"*.md; do [ -f "$f" ] && rules_count=$((rules_count + 1)); done
        echo "  ✓ $lang"
    done
    echo "  Installed $rules_count rule files"
    echo ""

    # ── 2. Skills → ~/.config/amp/skills/ ──
    echo "[2/6] Installing skills -> $AMP_SKILLS_DIR/"
    skills_count=0
    if [[ -d "$SCRIPT_DIR/skills" ]]; then
        mkdir -p "$AMP_SKILLS_DIR"
        cp -r "$SCRIPT_DIR/skills/." "$AMP_SKILLS_DIR/"
        skills_count=$(find "$SCRIPT_DIR/skills" -maxdepth 1 -mindepth 1 -type d | wc -l)
    fi
    echo "  Installed $skills_count skills"
    echo ""

    # ── 3. Agents → Skills (ecc-agent-*) ──
    echo "[3/6] Installing agents as skills -> $AMP_SKILLS_DIR/ecc-agent-*"
    agents_count=0
    if [[ -d "$SCRIPT_DIR/agents" ]]; then
        for f in "$SCRIPT_DIR/agents/"*.md; do
            [[ -f "$f" ]] || continue
            agent_name="$(basename "$f" .md)"
            skill_dir="$AMP_SKILLS_DIR/ecc-agent-$agent_name"
            mkdir -p "$skill_dir"

            # Extract description from frontmatter
            agent_desc="$(awk '/^description:/{sub(/^description: */, ""); print; exit}' "$f")"

            # Build SKILL.md: rewrite frontmatter, keep body
            {
                echo "---"
                echo "name: ecc-agent-$agent_name"
                echo "description: \"[ECC Agent] ${agent_desc}\""
                echo "origin: ECC"
                echo "---"
                echo ""
                # Everything after the closing --- of YAML frontmatter
                awk 'BEGIN{c=0} /^---$/{c++; next} c>=2{print}' "$f"
            } > "$skill_dir/SKILL.md"

            agents_count=$((agents_count + 1))
            echo "  ✓ ecc-agent-$agent_name"
        done
    fi
    echo "  Installed $agents_count agent skills"
    echo ""

    # ── 4. Commands → Skills (ecc-cmd-*) ──
    echo "[4/6] Installing commands as skills -> $AMP_SKILLS_DIR/ecc-cmd-*"
    cmds_count=0
    if [[ -d "$SCRIPT_DIR/commands" ]]; then
        for f in "$SCRIPT_DIR/commands/"*.md; do
            [[ -f "$f" ]] || continue
            cmd_name="$(basename "$f" .md)"
            skill_dir="$AMP_SKILLS_DIR/ecc-cmd-$cmd_name"
            mkdir -p "$skill_dir"

            # Extract description from frontmatter
            cmd_desc="$(awk '/^description:/{sub(/^description: */, ""); print; exit}' "$f")"

            # Build SKILL.md: rewrite frontmatter, keep body
            {
                echo "---"
                echo "name: ecc-cmd-$cmd_name"
                echo "description: \"[ECC Command /$cmd_name] ${cmd_desc}\""
                echo "origin: ECC"
                echo "---"
                echo ""
                awk 'BEGIN{c=0} /^---$/{c++; next} c>=2{print}' "$f"
            } > "$skill_dir/SKILL.md"

            cmds_count=$((cmds_count + 1))
            echo "  ✓ ecc-cmd-$cmd_name"
        done
    fi
    echo "  Installed $cmds_count command skills"
    echo ""

    # ── 5. AGENTS.md → ~/.config/amp/AGENTS.md ──
    echo "[5/6] Writing global AGENTS.md -> $AMP_AGENTS_FILE"
    if [[ -f "$AMP_AGENTS_FILE" ]]; then
        backup_file="${AMP_AGENTS_FILE}.bak.$(date +%Y%m%d-%H%M%S)"
        cp "$AMP_AGENTS_FILE" "$backup_file"
        echo "  Backed up existing -> $backup_file"
    fi

    mkdir -p "$(dirname "$AMP_AGENTS_FILE")"
    cat > "$AMP_AGENTS_FILE" <<'AGENTS_EOF'
# Everything Claude Code (ECC) — Global Agent Instructions

This configuration includes the full Everything Claude Code (ECC) plugin suite.

## Available ECC Skills

Use the `skill` tool to load any ECC skill. Skills are prefixed:
- `ecc-agent-*` — Specialized agents (planner, code-reviewer, architect, tdd-guide, etc.)
- `ecc-cmd-*` — Commands (plan, tdd, code-review, build-fix, verify, etc.)
- Other skills — Domain knowledge (coding-standards, backend-patterns, frontend-patterns, etc.)

## Development Context

- Write code first, explain after
- Prefer working solutions over perfect solutions
- Run tests after changes
- Keep commits atomic
- Priorities: (1) Get it working, (2) Get it right, (3) Get it clean

## Code Review Context

- Read thoroughly before commenting
- Prioritize issues by severity (critical > high > medium > low)
- Suggest fixes, don't just point out problems
- Check for security vulnerabilities
- Review checklist: Logic errors, edge cases, error handling, security, performance, readability, test coverage

## Research Context

- Read widely before concluding
- Document findings as you go
- Don't write code until understanding is clear
- Findings first, recommendations second
AGENTS_EOF
    echo "  ✓ AGENTS.md written"
    echo ""

    # ── 6. Amp settings (skills.path + MCP) ──
    echo "[6/6] Updating Amp settings -> $AMP_SETTINGS_FILE"
    mkdir -p "$(dirname "$AMP_SETTINGS_FILE")"

    # Use node (available in any ECC-compatible environment) to merge settings
    if command -v node >/dev/null 2>&1; then
        node -e "
const fs = require('fs');
const file = process.argv[1];
const eccDir = process.argv[2];

let settings = {};
try { settings = JSON.parse(fs.readFileSync(file, 'utf8')); } catch {}

// Add skills.path pointing to ECC repo skills (fallback source)
settings['amp.skills.path'] = eccDir + '/skills';

// Merge MCP servers (don't overwrite user-configured ones)
if (!settings['amp.mcpServers']) settings['amp.mcpServers'] = {};
const defaults = {
    memory: { command: 'npx', args: ['-y', '@modelcontextprotocol/server-memory'] },
    'sequential-thinking': { command: 'npx', args: ['-y', '@modelcontextprotocol/server-sequential-thinking'] },
    context7: { command: 'npx', args: ['-y', '@context7/mcp-server'] }
};
for (const [name, config] of Object.entries(defaults)) {
    if (!settings['amp.mcpServers'][name]) {
        settings['amp.mcpServers'][name] = config;
    }
}

fs.writeFileSync(file, JSON.stringify(settings, null, 2) + '\n');
" "$AMP_SETTINGS_FILE" "$SCRIPT_DIR"
        echo "  ✓ amp.skills.path set"
        echo "  ✓ MCP servers configured (memory, sequential-thinking, context7)"
    else
        echo "  Warning: node not found. Skipping settings.json update."
        echo "  Manually add amp.skills.path and amp.mcpServers to $AMP_SETTINGS_FILE"
    fi
    echo ""

    # ── Summary ──
    total=$((skills_count + agents_count + cmds_count))
    echo "================================================"
    echo "Done! ECC installed for Amp CLI & VS Code Extension"
    echo ""
    echo "  Rules:    $rules_count files  -> $RULES_DEST/"
    echo "  Skills:   $skills_count       -> $AMP_SKILLS_DIR/"
    echo "  Agents:   $agents_count       -> $AMP_SKILLS_DIR/ecc-agent-*"
    echo "  Commands: $cmds_count       -> $AMP_SKILLS_DIR/ecc-cmd-*"
    echo "  AGENTS.md:          -> $AMP_AGENTS_FILE"
    echo "  Settings:           -> $AMP_SETTINGS_FILE"
    echo ""
    echo "  Total skills available: $total"
    echo ""
    echo "Restart Amp to pick up all changes."
fi

# --- Kilo target ---
if [[ "$TARGET" == "kilo" ]]; then
    KILO_ROOT="${KILO_ROOT:-.kilocode}"
    KILO_RULES_DIR="$KILO_ROOT/rules"
    KILO_SKILLS_DIR="$KILO_ROOT/skills"
    KILO_WORKFLOWS_DIR="$KILO_ROOT/workflows"
    KILO_MCP_FILE="${KILO_MCP_FILE:-$KILO_ROOT/mcp.json}"
    KILO_AGENTS_FILE="${KILO_AGENTS_FILE:-AGENTS.md}"

    # If no languages specified, install all available language rule packs
    if [[ $# -eq 0 ]]; then
        set -- $(for dir in "$RULES_DIR"/*/; do
            name="$(basename "$dir")"
            [[ "$name" != "common" ]] && echo "$name"
        done)
        echo "No languages specified — installing all: $*"
    fi

    echo ""
    echo "Installing ECC for Kilo Code"
    echo "============================"
    echo ""

    mkdir -p "$KILO_RULES_DIR" "$KILO_SKILLS_DIR" "$KILO_WORKFLOWS_DIR"

    # ── 1. Rules → .kilocode/rules/ (namespaced files to avoid collisions) ──
    echo "[1/5] Installing rules -> $KILO_RULES_DIR/"
    rules_count=0
    for f in "$RULES_DIR/common/"*.md; do
        if [[ -f "$f" ]]; then
            cp "$f" "$KILO_RULES_DIR/common-$(basename "$f")"
            rules_count=$((rules_count + 1))
        fi
    done

    for lang in "$@"; do
        if [[ ! "$lang" =~ ^[a-zA-Z0-9_-]+$ ]]; then
            echo "  Error: invalid language name '$lang'. Skipping." >&2
            continue
        fi
        lang_dir="$RULES_DIR/$lang"
        if [[ ! -d "$lang_dir" ]]; then
            echo "  Warning: rules/$lang/ does not exist, skipping." >&2
            continue
        fi
        for f in "$lang_dir/"*.md; do
            if [[ -f "$f" ]]; then
                cp "$f" "$KILO_RULES_DIR/${lang}-$(basename "$f")"
                rules_count=$((rules_count + 1))
            fi
        done
        echo "  ✓ $lang"
    done
    echo "  Installed $rules_count rule files"
    echo ""

    # ── 2. Skills → .kilocode/skills/ ──
    echo "[2/5] Installing skills -> $KILO_SKILLS_DIR/"
    skills_count=0
    if [[ -d "$SCRIPT_DIR/skills" ]]; then
        cp -r "$SCRIPT_DIR/skills/." "$KILO_SKILLS_DIR/"
        skills_count=$(find "$SCRIPT_DIR/skills" -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d ' ')
    fi
    echo "  Installed $skills_count skills"
    echo ""

    # ── 3. Agents → Skills (ecc-agent-*) ──
    echo "[3/5] Installing agents as skills -> $KILO_SKILLS_DIR/ecc-agent-*"
    agents_count=0
    if [[ -d "$SCRIPT_DIR/agents" ]]; then
        for f in "$SCRIPT_DIR/agents/"*.md; do
            [[ -f "$f" ]] || continue
            agent_name="$(basename "$f" .md)"
            skill_dir="$KILO_SKILLS_DIR/ecc-agent-$agent_name"
            mkdir -p "$skill_dir"

            agent_desc="$(awk '/^description:/{sub(/^description: */, ""); print; exit}' "$f")"
            escaped_desc="${agent_desc//\"/\\\"}"

            {
                echo "---"
                echo "name: ecc-agent-$agent_name"
                echo "description: \"[ECC Agent] ${escaped_desc}\""
                echo "origin: ECC"
                echo "---"
                echo ""
                awk 'BEGIN{c=0} /^---$/{c++; next} c>=2{print}' "$f"
            } > "$skill_dir/SKILL.md"

            agents_count=$((agents_count + 1))
            echo "  ✓ ecc-agent-$agent_name"
        done
    fi
    echo "  Installed $agents_count agent skills"
    echo ""

    # ── 4. Commands → Workflows (ecc-*) ──
    echo "[4/5] Installing workflows -> $KILO_WORKFLOWS_DIR/ecc-*.md"
    workflows_count=0
    if [[ -d "$SCRIPT_DIR/commands" ]]; then
        for f in "$SCRIPT_DIR/commands/"*.md; do
            [[ -f "$f" ]] || continue
            cp "$f" "$KILO_WORKFLOWS_DIR/ecc-$(basename "$f")"
            workflows_count=$((workflows_count + 1))
        done
    fi
    echo "  Installed $workflows_count workflows"
    echo ""

    # ── 5. AGENTS.md + MCP template ──
    echo "[5/5] Writing AGENTS.md and MCP template"
    write_kilo_agents_file "$KILO_AGENTS_FILE" "$KILO_SKILLS_DIR" "$KILO_RULES_DIR" "$KILO_WORKFLOWS_DIR"
    echo "  ✓ AGENTS.md -> $KILO_AGENTS_FILE"

    if [[ -f "$SCRIPT_DIR/mcp-configs/mcp-servers.json" ]]; then
        mkdir -p "$(dirname "$KILO_MCP_FILE")"
        if command -v python3 >/dev/null 2>&1; then
            python3 - "$SCRIPT_DIR/mcp-configs/mcp-servers.json" "$KILO_MCP_FILE" <<'PY'
import json
import sys
from pathlib import Path

src = Path(sys.argv[1])
dst = Path(sys.argv[2])
data = json.loads(src.read_text(encoding="utf-8"))

servers = data.get("mcpServers")
if isinstance(servers, dict):
    for server in servers.values():
        if isinstance(server, dict) and server.get("type") == "http":
            server["type"] = "streamable-http"

dst.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
PY
            echo "  ✓ MCP template -> $KILO_MCP_FILE"
        else
            cp "$SCRIPT_DIR/mcp-configs/mcp-servers.json" "$KILO_MCP_FILE"
            echo "  ✓ MCP template (unmodified) -> $KILO_MCP_FILE"
        fi
    fi
    echo ""

    total_skills=$((skills_count + agents_count))
    echo "============================"
    echo "Done! ECC installed for Kilo Code"
    echo ""
    echo "  Rules:      $rules_count files    -> $KILO_RULES_DIR/"
    echo "  Skills:     $skills_count         -> $KILO_SKILLS_DIR/"
    echo "  AgentSkills:$agents_count         -> $KILO_SKILLS_DIR/ecc-agent-*"
    echo "  Workflows:  $workflows_count      -> $KILO_WORKFLOWS_DIR/ecc-*.md"
    echo "  AGENTS.md:                      -> $KILO_AGENTS_FILE"
    echo "  MCP file:                       -> $KILO_MCP_FILE"
    echo ""
    echo "  Total skills available in Kilo scope: $total_skills"
    echo ""
    echo "Reload Kilo Code to pick up newly installed skills/rules/workflows."
fi

# --- Antigravity target ---
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
