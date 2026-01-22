<!-- OPENSPEC:START -->
# OpenSpec Instructions

These instructions are for AI assistants working in this project.

Always open `@/openspec/AGENTS.md` when the request:
- Mentions planning or proposals (words like proposal, spec, change, plan)
- Introduces new capabilities, breaking changes, architecture shifts, or big performance/security work
- Sounds ambiguous and you need the authoritative spec before coding

Use `@/openspec/AGENTS.md` to learn:
- How to create and apply change proposals
- Spec format and conventions
- Project structure and guidelines

Keep this managed block so 'openspec update' can refresh the instructions.

<!-- OPENSPEC:END -->

# OpenSpec Integration for CardMind

This project uses **OpenSpec** for spec-driven development (SDD). All AI assistants should follow the OpenSpec workflow.

---

## OpenSpec Quick Reference

### Supported Slash Commands (Claude Code, Cursor, etc.)

| Command | Purpose |
|---------|---------|
| `/openspec:proposal <feature>` | Create a new change proposal |
| `/openspec:apply <change>` | Implement tasks from an approved change |
| `/openspec:archive <change>` | Archive completed change, merge into specs |

### Without Slash Commands

If your tool doesn't support slash commands, use natural language:

- *"Create an OpenSpec proposal for adding search functionality"*
- *"Apply the OpenSpec change for card creation"*
- *"Archive the completed OpenSpec change"*

---

## OpenSpec Workflow

```
1. DRAFT → 2. REVIEW → 3. IMPLEMENT → 4. ARCHIVE
   proposal     edit specs     tasks       merge to truth
```

### Step 1: Draft Proposal
```
You: "Create an OpenSpec proposal for [feature]"
AI:  Creates openspec/changes/<feature>/
     ├── proposal.md       # Why and what
     ├── tasks.md          # Implementation checklist
     └── specs/            # Delta showing changes
```

### Step 2: Review & Refine
```
You: "Add acceptance criteria for X"
AI:  Updates the proposal with scenarios
```

### Step 3: Implement
```
You: "Apply this change"
AI:  Works through tasks, updates specs as needed
```

### Step 4: Archive
```
You: "Archive this change"
AI:  Runs: openspec archive <change> --yes
     Specs updated, change moved to archive/
```

---

## Spec Location

| Path | Content |
|------|---------|
| `openspec/specs/` | All specifications (domain-driven structure) |
| `openspec/specs/domain/` | Domain models and business logic |
| `openspec/specs/api/` | Public API specifications |
| `openspec/specs/features/` | User-facing features |
| `openspec/specs/ui_system/` | UI design system |
| `docs/adr/` | Architecture decision records (Chinese) |
| `openspec/changes/` | Proposed changes (active) |

---

## Writing Specs (OpenSpec Format)

### Requirement Template

```markdown
### Requirement: <Feature Name>

The system SHALL <behavior>.

#### Scenario: <Scenario Name>
- GIVEN <precondition>
- WHEN <trigger>
- THEN <expected outcome>
```

### Example

```markdown
### Requirement: Card Creation

The system SHALL create a new card with a unique UUID v7 ID.

#### Scenario: Create card with valid input
- GIVEN the user is on the card creation screen
- WHEN the user submits title and content
- THEN create a new card with UUID v7 ID
- AND return the created card
```

---

## Related Documentation

- [OpenSpec Official Docs](https://openspec.dev/)
- [CardMind Spec Center](specs/README.md)
- [CardMind Architecture](../../docs/architecture/system_design.md)
- [ADRs](../../docs/adr/)

---

**Last Updated**: 2026-01-15
