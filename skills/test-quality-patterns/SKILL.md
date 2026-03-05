---
name: test-quality-patterns
description: Classification rules for determining whether a test genuinely verifies behavior (Verified), executes code without asserting its output (Shadowed), or does not exist (Missing). Used by CoverageMapper to map test coverage to behavioral guarantees.
user-invocable: false
allowed-tools: Read, Grep, Glob
---

# Test Quality Patterns

Domain expertise for classifying whether existing tests actually verify behavior. Use alongside `react-behavior-patterns` for complete behavioral coverage analysis.

## Iron Law

> **A TEST THAT CANNOT FAIL IS NOT A TEST — IT IS A LIE**
>
> Every test must be capable of failing when the behavior it targets breaks. If you can
> delete the feature and the test still passes, the test proves nothing. Assertion
> specificity is the only measure of test value. A rendered component with no behavioral
> assertion is a demo, not a test.

---

## Three-State Classification

Every behavior is exactly one of three states. No ambiguity, no partial credit.

### ✅ Verified

The test creates the conditions that trigger the behavior **and** asserts the specific observable outcome. A developer could break this behavior and the test would fail.

```typescript
// Verified — asserts specific role + content that would fail if behavior breaks
it('displays error message when status is error', () => {
  render(<UserCard status="error" message="Network failure" />);

  expect(screen.getByRole('alert')).toHaveTextContent('Network failure');
  expect(screen.queryByRole('main')).not.toBeInTheDocument();
});

// Verified — asserts callback payload, not just invocation
it('calls onDelete with the user id when delete is clicked', async () => {
  const onDelete = jest.fn();
  render(<UserCard user={mockUser} onDelete={onDelete} />);

  await userEvent.click(screen.getByRole('button', { name: /delete/i }));

  expect(onDelete).toHaveBeenCalledWith(mockUser.id);
  expect(onDelete).toHaveBeenCalledTimes(1);
});
```

### ⚠️ Shadowed

The test creates the conditions that trigger the behavior but its assertions are too weak to catch a regression. The test passes whether the behavior works correctly or not.

```typescript
// Shadowed — snapshot doesn't verify the behavior, only structure
it('renders loading state', () => {
  const { container } = render(<UserCard isLoading />);
  expect(container).toMatchSnapshot(); // passes even if skeleton is wrong
});

// Shadowed — existence check proves nothing about what's shown
it('shows error state', () => {
  render(<UserCard status="error" message="Network failure" />);
  expect(screen.getByTestId('user-card')).toBeInTheDocument(); // always true
});

// Shadowed — callback invocation without payload
it('calls onDelete when button clicked', async () => {
  const onDelete = jest.fn();
  render(<UserCard user={mockUser} onDelete={onDelete} />);
  await userEvent.click(screen.getByRole('button', { name: /delete/i }));
  expect(onDelete).toHaveBeenCalled(); // doesn't verify it was called with userId
});
```

### ❌ Missing

No test in any test file creates the conditions to trigger this behavior.

---

## Assertion Strength Rubric

When a test covers a behavior, rate assertion strength to identify Shadowed cases:

| Strength | Pattern | Detects Regression? |
|----------|---------|---------------------|
| **STRONG** | `expect(screen.getByRole('alert')).toHaveTextContent('Network failure')` | Yes — text and semantics |
| **STRONG** | `expect(onSubmit).toHaveBeenCalledWith({ email: 'a@b.com' })` | Yes — payload verified |
| **STRONG** | `expect(screen.queryByText('Loading')).not.toBeInTheDocument()` | Yes — absence asserted |
| **WEAK** | `expect(screen.getByRole('alert')).toBeInTheDocument()` | Only removal caught |
| **WEAK** | `expect(onDelete).toHaveBeenCalled()` | Only call count caught |
| **WEAK** | `expect(screen.getByText('Error')).toBeInTheDocument()` | Text caught, semantics not |
| **PHANTOM** | `expect(container).toMatchSnapshot()` | Structure only, not behavior |
| **PHANTOM** | `expect(container).toBeInTheDocument()` | Always true — proves nothing |
| **PHANTOM** | `expect(() => render(<C />)).not.toThrow()` | Proves no crash, nothing else |

**STRONG → Verified. WEAK → Verified (note it). PHANTOM → Shadowed.**

---

## React Testing Library Anti-Patterns

These patterns produce Shadowed coverage. Recognize them on sight.

### 1. Snapshot Tests for Behavioral States

```typescript
// SHADOWED — catches DOM structure changes, not behavioral regression
it('renders loading state', () => {
  const { container } = render(<Card isLoading />);
  expect(container).toMatchSnapshot();
});

// VERIFIED — asserts what the user actually sees
it('shows spinner and hides content while loading', () => {
  render(<Card isLoading />);
  expect(screen.getByRole('status', { name: /loading/i })).toBeInTheDocument();
  expect(screen.queryByText(cardContent)).not.toBeInTheDocument();
});
```

### 2. Implementation Queries Instead of Semantic Queries

```typescript
// SHADOWED — CSS class is implementation, not behavior
expect(wrapper.find('.error-banner')).toHaveLength(1);

// VERIFIED — role proves the semantic meaning (screen readers announce this)
expect(screen.getByRole('alert')).toHaveTextContent('Something went wrong');
```

### 3. Callback Invocation Without Payload Verification

```typescript
// SHADOWED — proves the button calls something; doesn't prove it passes the right data
expect(mockOnSubmit).toHaveBeenCalled();

// VERIFIED — proves the form collected and passed the correct values
expect(mockOnSubmit).toHaveBeenCalledWith({
  email: 'user@example.com',
  rememberMe: true,
});
```

### 4. Render-Only Tests

```typescript
// SHADOWED — proves no crash on render; proves nothing about what renders
it('renders without errors', () => {
  expect(() => render(<Component {...props} />)).not.toThrow();
});
```

### 5. Existence Without Specificity

```typescript
// SHADOWED — proves the element exists; doesn't prove it contains the right content
expect(screen.getByTestId('user-name')).toBeInTheDocument();

// VERIFIED — proves the right content is shown
expect(screen.getByTestId('user-name')).toHaveTextContent('Jane Doe');
```

---

## Coverage Signal Hierarchy

When multiple tests touch a behavior, use the highest-quality assertion to classify:

1. Role + text content → **Verified (STRONG)**
2. Role-only assertion → **Verified (WEAK)** — note it
3. Text content without role → **Verified (WEAK)** — note it
4. Snapshot assertion → **Shadowed (PHANTOM)**
5. Existence assertion (`toBeInTheDocument` no content) → **Shadowed (PHANTOM)**
6. Render-only (no assertion) → **Shadowed (PHANTOM)**
7. No test creates the conditions → **Missing**
