---
name: react-behavior-patterns
description: Taxonomy and detection rules for extracting user-observable behaviors from React components, TypeScript interfaces, and custom hooks. Used by BehaviorExtractor to enumerate the complete behavioral contract of a source file.
user-invocable: false
allowed-tools: Read, Grep, Glob
---

# React Behavior Patterns

Domain expertise for extracting observable behaviors from React/TypeScript source files. Every behavior extracted using this skill must satisfy the Iron Law.

## Iron Law

> **A BEHAVIOR NOT VERIFIABLE FROM THE OUTSIDE DOES NOT EXIST FOR TESTING PURPOSES**
>
> If a user cannot observe it, a test cannot verify it. Props are contracts. Render states
> are promises. Return values are the hook's output contract. Every TypeScript union member
> is a required test case. "This is just an internal implementation detail" is not a
> defense — if it changes visible output or return values, it is a behavior.

---

## Behavior Taxonomy

### 1. Props as Contracts

Every prop is a behavioral contract. Every distinct prop state changes what the component renders.

**Detection rules:**

| Prop type | Behaviors to extract |
|-----------|----------------------|
| `boolean` | 2 minimum: true state + false/undefined state |
| `string \| null` | 2: value present + null |
| `prop?: T` | 2: provided + omitted |
| `'a' \| 'b' \| 'c'` | 1 per member — non-negotiable |
| `callback: (x: T) => void` | 1 per trigger + what it is called with |
| `children?: ReactNode` | 2: with children + without |

```typescript
// This interface declares 7 behaviors minimum
interface UserCardProps {
  user: User | null;        // B1: user present, B2: user null
  isLoading: boolean;       // B3: loading state, B4: not loading
  onDelete: (id: string) => void; // B5: called with user.id on trigger
  variant: 'compact' | 'full';    // B6: compact layout, B7: full layout
}
```

### 2. Render States

Every conditional that changes visible output is a distinct behavior.

**Detection patterns:**

```typescript
{isLoading && <Spinner />}          // 2 behaviors: loading / not-loading
{error ? <Error /> : <Content />}   // 2 behaviors: error / success
{items.length === 0 && <Empty />}   // 2 behaviors: empty / populated
switch (status) { case ...: }       // 1 behavior per case branch
if (!data) return null;             // 1 behavior: renders nothing
```

**The four universal async states** — every component that fetches data has all four:

| State | Trigger | What renders |
|-------|---------|--------------|
| Idle | Initial mount | Placeholder or initial UI |
| Loading | Fetch in progress | Skeleton, spinner, or disabled state |
| Error | Fetch failed | Error message, retry option |
| Success | Data available | Full content |

### 3. User Interactions

Every event handler is a behavior. The behavior is the observable outcome, not the event.

```typescript
onClick={handleDelete}   // Behavior: what changes when user clicks
onChange={handleSearch}  // Behavior: how component responds to input
onSubmit={handleForm}    // Behavior: what is submitted and to whom
```

**Extract the outcome, not the handler:**
```
WRONG: "user can click the delete button"
RIGHT: "clicking delete calls onDelete with the current item's id"
```

### 4. TypeScript Type-Driven Edge Cases

The type system is a test specification. Every boundary in a type is a required behavior.

```typescript
user?: User              // Behavior: component when user is undefined
items: Item[]            // Behavior: component when items is []
count: number            // Behavior: component when count is 0
error?: string           // Behavior: component when error is "" (empty string is falsy!)
```

**Discriminated unions — enumerate every member:**

```typescript
type Status =
  | { status: 'idle' }
  | { status: 'loading' }
  | { status: 'error'; message: string }
  | { status: 'success'; data: User[] };
// = exactly 4 behaviors. All required. No exceptions.
```

### 5. Custom Hooks

Hooks have behavioral contracts expressed through their **return values** and the **state transitions** those values undergo. The return value shape is the hook's observable output — equivalent to a component's rendered DOM.

**Detection rules:**

| Hook return element | Behaviors to extract |
|--------------------|----------------------|
| `value: T \| null` | 2: value present + null |
| `isLoading: boolean` | 2: true state + false state |
| `error: string \| null` | 2: error set + null |
| `fn: (x: T) => void` | 1 per trigger condition + what changes in return values after call |
| Initial state on mount | Always 1 behavior: initial return shape before any action |

```typescript
function useAuth() {
  return {
    user: User | null,      // B1: null on mount, B2: User after login
    isLoading: boolean,     // B3: true during login, B4: false when resolved
    error: string | null,   // B5: null on success, B6: error string on failure
    login: (creds) => void, // B7: sets user on success, B8: sets error on failure
    logout: () => void,     // B9: clears user and resets to initial state
  }
}
// = 9 behaviors from one hook
```

**Key difference from components:** hooks don't render — their verifiable signals are `result.current` value changes. Tests use `renderHook` and assert on return values:

```typescript
// Verifiable signal for B2:
const { result } = renderHook(() => useAuth());
await act(() => result.current.login(validCredentials));
expect(result.current.user).toEqual(mockUser);
expect(result.current.isLoading).toBe(false);
```

**Async state transitions** — every hook with an async action has this sequence:
1. Before action: initial state
2. During action: `isLoading: true`, previous value still present
3. After success: value updated, `isLoading: false`, `error: null`
4. After failure: value unchanged, `isLoading: false`, `error` set

All four transitions are distinct behaviors.

### 6. Side Effects

Observable outputs beyond rendered HTML or return values.

**Detection patterns:**

```typescript
// API calls → loading/error/success state behaviors
const { data } = useQuery(...)

// Navigation → route change behavior
router.push('/dashboard')

// Context mutation → downstream consumers update
dispatch({ type: 'SET_USER', payload: user })

// Storage → persistence behavior
localStorage.setItem('token', value)
```

---

## Risk Assignment

| Risk | Criteria |
|------|----------|
| **CRITICAL** | Core user journey; callback payload correctness; auth/data mutations |
| **HIGH** | Error and loading states; null/undefined type edges; async transitions |
| **MEDIUM** | Style variants affecting layout; secondary interaction paths |
| **LOW** | Visual-only variants; informational states with no user action |

---

## Common Misses

These behaviors are routinely overlooked — check for them explicitly:

- Empty array state (`items: []`) — almost always missing from tests
- `error=""` (empty string is falsy — error guard silently skips)
- Callback called with wrong payload vs not called at all
- Hook state during async action (the loading transition), not just before/after
- Disabled state while operation is in progress
- Absence behaviors — things that should NOT render in a given state
