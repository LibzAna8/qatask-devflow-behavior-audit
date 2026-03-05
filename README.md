# devflow-behavior-audit

QA behavior coverage analysis for React + TypeScript. Surfaces every behavior a component promises and identifies which promises have no test guard.

## The Command: `/behavior-audit`

### Why this command

Code review finds bad code. `/behavior-audit` finds confident lies.

A React component's TypeScript interface is a behavioral specification. Every prop, every union member, every nullable type is a promise the component makes to its consumers. When those promises have no test, they can break silently — a refactor, a null check removed, a default value changed — and nothing fails.

`/behavior-audit` asks the question `/code-review` doesn't: *"Of everything this component can do, how much of it will a test catch if it breaks?"*

It distinguishes three states that standard coverage tools collapse into one:

- **✅ Verified** — a test triggers the behavior and asserts its specific observable output
- **⚠️ Shadowed** — a test runs the code but its assertions are too weak to catch a regression (snapshot tests, `toBeInTheDocument()` without content, callbacks without payload checks)
- **❌ Missing** — no test exercises this behavior at all

The **Shadowed** category is what developers don't know about. A snapshot test on a loading state looks like coverage — it isn't. It will pass even if the loading indicator never renders. `/behavior-audit` finds these blind spots.

---

## Installation

```bash
git clone https://github.com/LibzAna8/qatask-devflow-behavior-audit
cd qatask-devflow-behavior-audit
bash install.sh
```

---

## Usage

Open Claude Code in any React + TypeScript project on a feature branch:

```bash
cd your-react-project
git checkout your-feature-branch
claude
```

Then run:

```
/behavior-audit
```

No arguments. No running dev server. No additional configuration.

**Requirements:**
- A git repository with a base branch (`main`, `master`, or `develop`)
- Changed `.ts` / `.tsx` source files on the current branch

---

## What It Produces

For each changed component or hook, the audit:

1. **Extracts every observable behavior** from the TypeScript interface and render logic — props contracts, render states, user interactions, hook return values, type-driven edge cases
2. **Locates and maps existing tests** to those behaviors, classifying each as Verified, Shadowed, or Missing
3. **Produces a risk-ranked report** at `.docs/behavior-audit/{branch}/gap-report.md` with copy-paste ready test specs for every gap

### Example output

```
## Merge Risk: HIGH

> 3 HIGH behaviors have no test guard — regressions would ship silently.

## Coverage Summary
| Status      | Count | %   |
|-------------|-------|-----|
| ✅ Verified  |   4   | 22% |
| ⚠️ Shadowed  |   2   | 11% |
| ❌ Missing   |  12   | 67% |

## P0 — Fix Before Merge

### ❌ UserCard — renders null when `user` is null
Risk: HIGH | File: src/components/UserCard.tsx

Why this matters: any consumer passing null gets a silent render failure.

Test to write:
  it('renders nothing when user is null', () => {
    const { container } = render(<UserCard user={null} onDelete={jest.fn()} />);
    expect(container.firstChild).toBeNull();
  });

### ⚠️ UserCard — calls onDelete with user.id when delete clicked
Problem: test asserts onDelete was called, not what it was called with.
Fix: expect(onDelete).toHaveBeenCalledWith(mockUser.id)
```

### Report structure

```
.docs/behavior-audit/
└── {branch-slug}/
    ├── behaviors/          # Per-file behavior inventories
    ├── coverage/           # Per-file coverage classifications
    └── gap-report.md       # Final ranked report (the deliverable)
```

---

## Architecture

Three agents, clean separation:

| Agent | Job |
|-------|-----|
| `BehaviorExtractor` | Reads a source file, enumerates every observable behavior using the TypeScript interface as a spec |
| `CoverageMapper` | Finds test files, maps each test to behaviors, classifies Verified / Shadowed / Missing |
| `GapSynthesizer` | Aggregates all inventories and maps, risk-ranks gaps, writes test specifications for P0/P1 items |

Two skills encode the methodology:

| Skill | Iron Law |
|-------|---------|
| `react-behavior-patterns` | *A behavior not verifiable from the outside does not exist for testing purposes* |
| `test-quality-patterns` | *A test that cannot fail is not a test — it is a lie* |

The command orchestrates. The agents execute. The skills encode why.
