---
description: QA behavior coverage audit — identifies every observable behavior in changed React+TypeScript components and surfaces which have no test guard
---

# Command: /behavior-audit

Audit behavioral test coverage on the current branch. For every observable behavior declared by changed React/TypeScript components and hooks, determine whether it is **verified** (tested and meaningfully asserted), **shadowed** (executed but not genuinely asserted), or **missing** (no test exists).

## Usage

```
/behavior-audit
```

Run from any React+TypeScript project on a feature branch.

## Phases

### Phase 0: Discover

Identify the base branch and all changed TypeScript source files:

```bash
BRANCH=$(git rev-parse --abbrev-ref HEAD)
BRANCH_SLUG=$(echo "$BRANCH" | tr '/' '-')

# Detect base branch — try tracking branch first, then look for common branches locally
BASE=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null | sed 's|origin/||' | sed 's|upstream/||')
if [ -z "$BASE" ]; then
  for b in main master develop; do
    if git show-ref --verify --quiet refs/remotes/origin/$b 2>/dev/null || \
       git show-ref --verify --quiet refs/heads/$b 2>/dev/null; then
      BASE=$b
      break
    fi
  done
fi
BASE=${BASE:-main}

# All changed .ts/.tsx source files (exclude test files)
SOURCE_FILES=$(git diff --name-only $BASE...HEAD 2>/dev/null | \
  grep -E '\.(ts|tsx)$' | \
  grep -v -E '\.(test|spec)\.(ts|tsx)$' | \
  grep -v '__tests__')
```

**If SOURCE_FILES is empty:** output "No source changes found between this branch and `{BASE}`." and stop.

Create output directories:
```bash
mkdir -p .docs/behavior-audit/$BRANCH_SLUG/behaviors
mkdir -p .docs/behavior-audit/$BRANCH_SLUG/coverage
```

### Phase 1: Extract Behaviors (Parallel)

For each source file, spawn a `BehaviorExtractor` agent. Launch **all in a single message** so they run in parallel:

```
Task(
  subagent_type: "BehaviorExtractor",
  prompt: "FILE: {source_file_path}
OUTPUT: .docs/behavior-audit/{branch-slug}/behaviors/{file-slug}.md"
)
```

Where `{file-slug}` is the source file path with `/` replaced by `-` and extension removed.

**Wait for all extractors to complete before proceeding.**

### Phase 2: Map Coverage (Parallel)

For each source file, spawn a `CoverageMapper` agent. Launch **all in a single message**:

```
Task(
  subagent_type: "CoverageMapper",
  prompt: "BEHAVIORS: .docs/behavior-audit/{branch-slug}/behaviors/{file-slug}.md
SOURCE_FILE: {source_file_path}
OUTPUT: .docs/behavior-audit/{branch-slug}/coverage/{file-slug}.md"
)
```

The CoverageMapper is responsible for locating its own test files. No test file matching happens in this command.

**Wait for all mappers to complete before proceeding.**

### Phase 3: Synthesize

Before spawning the synthesizer, identify source files that have no corresponding coverage map (i.e., CoverageMapper found no test files for them):

```bash
UNTESTED=""
for f in $SOURCE_FILES; do
  slug=$(echo "$f" | tr '/' '-' | sed 's/\.[^.]*$//')
  if [ ! -f ".docs/behavior-audit/$BRANCH_SLUG/coverage/${slug}.md" ]; then
    UNTESTED="$UNTESTED,$f"
  fi
done
UNTESTED=${UNTESTED#,}  # strip leading comma
[ -z "$UNTESTED" ] && UNTESTED="none"
```

Spawn one `GapSynthesizer` agent:

```
Task(
  subagent_type: "GapSynthesizer",
  prompt: "BEHAVIORS_DIR: .docs/behavior-audit/{branch-slug}/behaviors/
COVERAGE_DIR: .docs/behavior-audit/{branch-slug}/coverage/
UNTESTED: {untested-files-or-none}
OUTPUT: .docs/behavior-audit/{branch-slug}/gap-report.md"
)
```

### Phase 4: Report

Display the summary from the gap report:

- Branch and base branch
- Merge risk level
- Behavior counts: ✅ Verified / ⚠️ Shadowed / ❌ Missing
- Top P0 and P1 gaps (names and one-line descriptions only)
- Full report path: `.docs/behavior-audit/{branch-slug}/gap-report.md`

## Architecture

```
/behavior-audit (orchestrator — spawns agents only, does no QA work itself)
│
├─ Phase 0: Branch + source file discovery (bash)
│  └─ Detects base branch without network dependency
│
├─ Phase 1: Behavior extraction (PARALLEL)
│  └─ BehaviorExtractor × N  (one per changed source file)
│
├─ Phase 2: Coverage mapping (PARALLEL)
│  └─ CoverageMapper × N  (one per source file — locates its own test files)
│
├─ Phase 3: Synthesis
│  └─ GapSynthesizer  (aggregates all inventories → risk-ranked report)
│
└─ Phase 4: Display summary to user
```

## Principles

1. **Orchestration only** — This command finds changed files and spawns agents. All QA reasoning happens inside agents.
2. **No source-to-test matching here** — CoverageMapper owns test file discovery using its domain knowledge of React project conventions.
3. **Parallel phases** — All Phase 1 agents launch together; all Phase 2 agents launch together.
4. **Three states, no ambiguity** — Verified, Shadowed, or Missing.
5. **Persist findings** — All output written to `.docs/behavior-audit/` so results survive the session.
