# ECC to Kilo Code Adaptation Plan

**Created:** 2026-02-24  
**Last Updated:** 2026-02-24  
**Status:** Implementation-ready  
**Objective:** Enable ECC capabilities in Kilo Code with a deterministic installer path.

---

## Executive Summary

This plan aligns ECC adaptation with Kilo Code's verified configuration model.

### Key Corrections from Earlier Draft

1. Kilo uses multiple configuration surfaces, not a single AGENTS-only model.
2. Rules should remain in `.kilocode/rules/` (not fully collapsed into AGENTS.md).
3. Skills should be installed in `.kilocode/skills/` (workspace) and/or `~/.kilocode/skills/` (global).
4. Commands map best to Kilo workflows in `.kilocode/workflows/`.
5. AGENTS.md is supported and useful, but it should complement rules/skills/workflows.

---

## Canonical Kilo Structure (Verified)

Workspace-level:

```text
project-root/
├── AGENTS.md
├── opencode.json                 # Optional CLI/project config
└── .kilocode/
    ├── skills/
    ├── rules/
    ├── workflows/
    └── mcp.json
```

Global-level:

```text
~/.config/kilo/opencode.json      # CLI global config
~/.kilocode/skills/
~/.kilocode/rules/
~/.kilocode/workflows/
~/.kilocode/cli/global/settings/mcp_settings.json
```

---

## Component Mapping

### 1. ECC Skills -> Kilo Skills

- Source: `skills/*/SKILL.md`
- Target: `.kilocode/skills/<skill-name>/SKILL.md`
- Action: direct copy (already compatible with SKILL.md + frontmatter model).

### 2. ECC Rules -> Kilo Rules

- Source: `rules/common/*.md` + language directories.
- Target: `.kilocode/rules/`.
- Action: install as namespaced rule files to avoid collisions:
  - `common-<filename>.md`
  - `<language>-<filename>.md`

This preserves both common and language-specific guidance without overwrite.

### 3. ECC Agents -> Kilo Skills

- Source: `agents/*.md`
- Target: `.kilocode/skills/ecc-agent-<agent-name>/SKILL.md`
- Action: convert each agent into a triggerable Kilo skill by rewriting frontmatter:
  - `name: ecc-agent-<agent-name>`
  - `description: [ECC Agent] ...`

### 4. ECC Commands -> Kilo Workflows

- Source: `commands/*.md`
- Target: `.kilocode/workflows/ecc-<command>.md`
- Action: copy command documents as workflow markdown.

### 5. Hooks -> Guidance Layer

Kilo does not use Claude-style hook wiring in the same way.

- Do not install ECC hook runtime config as executable Kilo hooks.
- Expose hook intent via:
  - `AGENTS.md` guardrails
  - skills/workflows that reproduce high-value behavior.

### 6. MCP -> Project Template

- Source: `mcp-configs/mcp-servers.json`
- Target: `.kilocode/mcp.json`
- Action: install as a starter MCP config for Kilo project usage.
- Compatibility adaptation: normalize `type: "http"` to `type: "streamable-http"` for remote entries.

---

## AGENTS.md Role in Kilo

AGENTS.md should be used as a top-level behavioral contract and ECC index, not as the only rule container.

Recommended AGENTS.md sections:

1. Installed ECC assets (`.kilocode/skills`, `.kilocode/rules`, `.kilocode/workflows`)
2. How to choose skills vs workflows
3. Safety boundaries (destructive commands, secrets handling)
4. Review/test expectations before completion

---

## Installer Requirements (Kilo Target)

Add `--target kilo` to `install.sh` with the following behavior:

1. Default install root: `.kilocode` (workspace-local).
2. If no languages are passed, install all available language rule sets.
3. Install common + selected language rules to `.kilocode/rules/` with namespaced filenames.
4. Install all ECC skills to `.kilocode/skills/`.
5. Install agents as `ecc-agent-*` skills.
6. Install commands as `ecc-*` workflows.
7. Install `.kilocode/mcp.json` template from `mcp-configs/mcp-servers.json` with HTTP transport normalization.
8. Write/update root `AGENTS.md` with backup if one already exists.
9. Print a clear summary of installed counts and paths.

Non-goals for initial implementation:

- No forced modification of global `~/.config/kilo/opencode.json`.
- No aggressive rewriting of user-authored AGENTS.md beyond backup + replace in target mode.

---

## Validation Checklist

After installer run:

1. `.kilocode/skills/` exists and contains ECC skills.
2. `.kilocode/rules/` exists and contains `common-*` and selected `<lang>-*` files.
3. `.kilocode/workflows/` contains `ecc-*.md` workflow files.
4. `.kilocode/mcp.json` exists and is valid JSON.
5. `AGENTS.md` exists at project root with ECC references.
6. `bash -n install.sh` passes.

Optional checks:

- `rg -n "name: ecc-agent-" .kilocode/skills`
- `rg -n "^# " .kilocode/workflows/ecc-*.md`
- `jq empty .kilocode/mcp.json`

---

## Execution Plan

1. Update this adaptation plan (done).
2. Implement `--target kilo` in installer.
3. Run installer in current workspace:
   - `./install.sh --target kilo`
4. Verify installed assets and summarize output.

---

## References

- Kilo docs root: https://kilo.ai/docs
- Kilo custom rules: https://kilo.ai/docs/customize/custom-rules
- Kilo custom modes: https://kilo.ai/docs/customize/custom-modes
- Kilo skills: https://kilo.ai/docs/customize/skills
- Kilo workflows: https://kilo.ai/docs/customize/workflows
- Kilo AGENTS.md: https://kilo.ai/docs/customize/agents-md
- Kilo MCP in CLI: https://kilo.ai/docs/automate/mcp/using-in-cli
- Kilo MCP in extension: https://kilo.ai/docs/automate/mcp/using-in-kilo-code
- Kilo runtime config schema: https://app.kilo.ai/config.json

