# Concurrency Safety Audit Prompt

Use this prompt to perform a comprehensive review of concurrency and thread-safety in the codebase.

---

**"Perform a comprehensive concurrency and thread-safety audit of this codebase. Identify all potential concurrency issues, race conditions, and unsafe patterns. Specifically investigate:**

**1. Sendable conformance issues:**
   - Every `@unchecked Sendable` type - is it truly safe or hiding problems?
   - Types that should be `Sendable` but aren't
   - Non-Sendable types being passed across concurrency boundaries
   - Closures capturing non-Sendable state

**2. Actor isolation problems:**
   - Non-isolated properties that should be isolated
   - Improper access to actor state from non-isolated contexts
   - Actor reentrancy issues (suspension points causing unexpected state changes)
   - Missing `await` keywords or synchronization

**3. Data races and shared mutable state:**
   - Global variables or singletons accessed from multiple threads
   - Class properties modified without synchronization
   - Collections (arrays, dictionaries) mutated concurrently
   - Weak references and race conditions during deallocation

**4. AsyncSequence and async/await issues:**
   - Iterators with shared mutable state
   - Multiple concurrent iterations over single-consumer sequences
   - Task cancellation not properly handled
   - Resources not cleaned up when async operations fail

**5. Lock and synchronization problems:**
   - Missing locks around critical sections
   - Potential deadlocks (nested locks, circular waits)
   - Locks held across suspension points (async calls)
   - Incorrect use of `OSAllocatedUnfairLock`, `NSLock`, etc.

**6. Task and structured concurrency issues:**
   - Unstructured tasks (`Task { }`) that leak or aren't properly tracked
   - TaskGroup not handling errors correctly
   - Child tasks outliving parents
   - Race conditions in task cancellation

**7. MainActor and UI thread safety:**
   - UI updates happening off the main thread
   - Missing `@MainActor` annotations
   - Unnecessary main thread hops causing performance issues

**8. Initialization and lifecycle races:**
   - Lazy properties accessed concurrently before initialization
   - Race conditions in `init` or `deinit`
   - Escaping `self` before full initialization
   - Cleanup code running while operations are still in progress

**9. Low-level concurrency primitives:**
   - Unsafe pointer usage across threads
   - Atomic operations used incorrectly
   - Manual memory management with concurrent access
   - C interop that isn't thread-safe

**10. Subtle logic bugs:**
   - Time-of-check vs time-of-use (TOCTOU) bugs
   - Assumptions about execution order that don't hold
   - Missing happens-before relationships
   - Non-atomic check-then-act patterns

**For each issue found, provide:**
   - **Location**: File and line number
   - **Severity**: Critical, High, Medium, or Low
   - **Explanation**: Why it's unsafe and what could go wrong
   - **Example scenario**: How the bug could manifest at runtime
   - **Recommendation**: The correct/safe approach

**Be systematic and thorough. Check every file that involves concurrency, async/await, actors, tasks, locks, or shared state. Look for both obvious issues and subtle edge cases.**"

---

## Usage

Copy the prompt above and provide it to a code review tool or assistant. For best results:

1. Run on the entire codebase, not just individual files
2. Review all findings carefully - some may be false positives
3. Prioritize fixing Critical and High severity issues first
4. Consider adding automated testing for race conditions where possible
5. Document any intentional `@unchecked Sendable` usage with justification

## Common Issues to Watch For

- **`@unchecked Sendable`**: Often indicates a shortcut that may not be safe
- **`NSLock` with `await`**: Never hold a lock across a suspension point
- **Weak self in actors**: Usually unnecessary and can cause confusion
- **Mutable state in closures**: Can cause races if the closure is `@Sendable`
- **Single-consumer iterators marked Sendable**: AsyncIterators typically aren't thread-safe
