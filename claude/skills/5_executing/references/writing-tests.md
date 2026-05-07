# Writing Tests

Reference for writing effective tests during TDD. Load when writing or changing tests, adding mocks, or when stuck.

## Good Tests

| Quality | Good | Bad |
|---------|------|-----|
| Minimal | One behavior per test | `test('validates email and domain and whitespace')` |
| Clear | Name describes behavior | `test('test1')` |
| Real | Tests actual code | Tests mock existence |

**Good example:**
```typescript
test('retries failed operations 3 times', async () => {
  let attempts = 0;
  const operation = () => {
    attempts++;
    if (attempts < 3) throw new Error('fail');
    return 'success';
  };
  const result = await retryOperation(operation);
  expect(result).toBe('success');
  expect(attempts).toBe(3);
});
```

**Bad example:**
```typescript
test('retry works', async () => {
  const mock = jest.fn()
    .mockRejectedValueOnce(new Error())
    .mockResolvedValueOnce('success');
  await retryOperation(mock);
  expect(mock).toHaveBeenCalledTimes(2); // tests mock, not behavior
});
```

## Test Levels and Coverage

Aim for high test coverage. Every new function, method, branch, and edge case should have a test. When in doubt, write the test.

### Unit Tests

Test one function/method in isolation. The foundation of coverage.

- Fast, deterministic, no external dependencies (DB, network, filesystem)
- Mock only external boundaries (APIs, databases, file I/O) — never mock the thing under test
- Cover: happy path, edge cases, error cases, boundary values, invalid inputs
- Every public function/method gets at least one unit test
- Every branch (if/else, switch, ternary) should be exercised

```typescript
// Test happy path AND edge cases for the same function
test('parseAge returns number for valid input', () => {
  expect(parseAge('25')).toBe(25);
});
test('parseAge returns 0 for zero', () => {
  expect(parseAge('0')).toBe(0);
});
test('parseAge throws for negative', () => {
  expect(() => parseAge('-1')).toThrow('Age must be positive');
});
test('parseAge throws for non-numeric', () => {
  expect(() => parseAge('abc')).toThrow('Invalid number');
});
test('parseAge throws for empty string', () => {
  expect(() => parseAge('')).toThrow('Age required');
});
```

### Integration Tests

Test components working together with real dependencies where practical.

- Use real implementations, not mocks (real DB with test data, real API clients against test servers)
- Cover: data flow between modules, API request/response cycles, database read/write roundtrips, component rendering with real children
- Slower than unit tests — write fewer but cover critical paths

```typescript
test('creating a user persists to DB and returns from API', async () => {
  const res = await request(app).post('/api/users').send({ name: 'Alice' });
  expect(res.status).toBe(201);

  const user = await db.users.findById(res.body.id);
  expect(user.name).toBe('Alice');
});
```

### When to Use Which

| Use unit tests for | Use integration tests for |
|---|---|
| Pure logic, calculations, transformations | Wiring between components |
| Input validation, parsing | API endpoints end-to-end |
| Error handling branches | Database operations (CRUD roundtrips) |
| Edge cases and boundary values | Authentication/authorization flows |
| Individual component rendering | Multi-component interactions |

### Coverage Goal

- Every public function: at least happy path + one error case
- Every conditional branch: exercised by a test
- Every edge case from the spec: has a dedicated test
- Prefer many small focused tests over few large ones — easier to diagnose failures
- If a bug is found later, write a regression test BEFORE fixing it

## When Stuck

| Problem | Solution |
|---------|----------|
| Don't know how to test | Write the wished-for API first. Write the assertion first. |
| Test too complicated | Design too complicated. Simplify the interface. |
| Must mock everything | Code too coupled. Use dependency injection. |
| Test setup huge | Extract helpers. Still complex? Simplify design. |

## Testing Anti-Patterns

### 1. Testing Mock Behavior

Asserting on mock elements (e.g., `getByTestId('sidebar-mock')`).

**Gate:** "Am I testing real component behavior or just mock existence?"
If mock existence: delete the assertion or unmock the component.

### 2. Test-Only Methods in Production

Adding `destroy()` or cleanup methods to production classes only called in tests.

**Gate:** "Is this method only used by tests?"
If yes: put it in test utilities instead.

### 3. Mocking Without Understanding Dependencies

Mocking a high-level method that has side effects the test depends on.

**Gate:** Before mocking, ask:
1. What side effects does the real method have?
2. Does this test depend on any of them?
3. Run the test with the real implementation FIRST, then add minimal mocking at the right level.

### 4. Incomplete Mocks

Only mocking fields you know the immediate test uses. Downstream code may silently depend on omitted fields.

**Rule:** Mock the COMPLETE data structure as it exists in reality.

### 5. Tests as Afterthought

Declaring implementation complete without tests.

**Fix:** Follow TDD. Tests are part of implementation, not optional follow-up.

## Warning Signs of Bad Mocks

- Mock setup longer than test logic
- Mocking everything to make test pass
- Mocks missing methods real components have
- Test breaks when mock changes
- Can't explain why mock is needed

If mocks are too complex, consider integration tests with real components instead.

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Too simple to test" | Simple code breaks. Test takes 30 seconds. |
| "I'll test after" | Tests passing immediately prove nothing. |
| "Already manually tested" | Ad-hoc is not systematic. No record, can't re-run. |
| "Keep code as reference" | You'll adapt it. That's testing after. Delete means delete. |
| "TDD will slow me down" | TDD is faster than debugging. |

## Verification Checklist

Before marking a task complete:

- [ ] Every new function/method has a test (unit test minimum)
- [ ] Every conditional branch is exercised by a test
- [ ] Watched each test fail before implementing
- [ ] Each test failed for expected reason
- [ ] Wrote minimal code to pass each test
- [ ] All tests pass (unit + integration)
- [ ] Output clean (no errors, warnings)
- [ ] Tests use real code (mocks only at external boundaries)
- [ ] Edge cases, error cases, and boundary values covered
- [ ] Critical paths have integration tests
- [ ] Bug found? Regression test written before fix
