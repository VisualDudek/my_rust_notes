## Intro

Can a Rust slice represent filtered data? I am thinking about an exercise like this:

```rust
fn ex7_middle_slice(numbers: &[i32]) -> &[i32] {
    &numbers[1..numbers.len() - 1]
}
```

Here, returning a slice works because the result refers to a contiguous region of the original input slice.

But what if I wanted to return only the even numbers from `numbers`?

My understanding is that returning `&[i32]` would not be possible in the general case. A slice is essentially a fat pointer consisting of a pointer to the first element and a length, so it can only describe a contiguous region of memory. Even numbers in the original slice may be located at non-contiguous addresses.

For example:

```text
[1, 2, 3, 4, 5, 6]
    ^     ^     ^
```

The values `2`, `4`, and `6` do not form one contiguous region in the original slice, so they cannot be represented as a single `&[i32]`.

One alternative would be to return a filtered iterator, for example:

```rust
numbers.iter().filter(|&&x| x % 2 == 0)
```

However, an iterator is stateful and is consumed as it is iterated over, so it behaves differently from a reusable slice.

What would be the idiomatic Rust solution here?

Would you recommend:

* returning an iterator,
* allocating a new `Vec<i32>`,
* returning a `Vec<&i32>`,
* or using another approach?

Your reasoning is exactly right, and it's a great instinct to check. A slice `&[i32]` is fundamentally a `(pointer, length)` pair into a **contiguous** region of memory. If the even numbers aren't contiguous in the original buffer, there's no way to describe "just the evens" with a single pointer+length — you'd need multiple disjoint ranges, which a slice cannot express.

So `fn evens(numbers: &[i32]) -> &[i32]` is only satisfiable if you either get lucky (the evens already happen to be a contiguous run) or you physically **reorder** the underlying data so they become contiguous. That reordering insight is actually the key to one of the real solutions below.

## Option 1 — In-place partition, return a real slice (zero allocation)

If you're allowed to take `&mut [i32]` instead of `&[i32]`, you can *rearrange* the slice so all evens come first, then return a sub-slice of the front. This is the same idea behind `slice::partition_point` / quicksort's partition step, or `Vec::retain`'s swap-remove-like shuffling.

```rust
/// Reorders `numbers` so all even values come first (order not preserved),
/// then returns a slice covering just those even values.
fn partition_evens(numbers: &mut [i32]) -> &[i32] {
    let mut write = 0;
    for read in 0..numbers.len() {
        if numbers[read] % 2 == 0 {
            numbers.swap(write, read);
            write += 1;
        }
    }
    &numbers[..write]
}
```

This is genuinely idiomatic for performance-sensitive code (it's basically what `Vec::retain` and the standard library's own partitioning routines do internally) — **zero heap allocation**, single pass, real slice semantics. The trade-off: it mutates the caller's data and doesn't preserve relative order of the evens (a stable partition would need either extra memory or a slower algorithm).

If you need order preserved *and* in-place, that's a stable partition — doable but costs either O(n) extra space or a rotation-based algorithm (more advanced, not usually worth it unless order matters).

## Option 2 — Return an owned `Vec<i32>` (simplest, most common)

If contiguity isn't achievable or desirable, the standard move is to stop promising a slice and just hand back ownership of a new buffer:

```rust
fn evens(numbers: &[i32]) -> Vec<i32> {
    numbers.iter().copied().filter(|n| n % 2 == 0).collect()
}
```

This is what 90% of real-world Rust code does for "filter and give me the results" — allocation is cheap relative to the clarity you get, and `Vec<i32>` derefs to `&[i32]` anywhere a slice is expected via `Deref<Target = [i32]>`, so callers barely notice the difference.

## Option 3 — Return a lazy iterator (zero allocation, but not a slice)

If you don't need a concrete buffer at all — just something the caller can iterate — return `impl Iterator`:

```rust
fn evens(numbers: &[i32]) -> impl Iterator<Item = &i32> {
    numbers.iter().filter(|n| **n % 2 == 0)
}
```

You correctly flagged the trap here: an iterator is lazy and single-use — it doesn't "contain" values, it *produces* them once, on demand, via repeated `.next()` calls. That's not a downside so much as a different contract: this is perfect when the caller is going to consume it once anyway (e.g. `for x in evens(&data) { ... }` or `.sum()`), because you avoid ever materializing an intermediate buffer.

## Recommendation

| Goal | Choice |
|---|---|
| Learning exercise fidelity to "return a slice" | Option 1 (in-place partition) — this is the *only* way to honestly return `&[i32]` |
| Real-world "give me the evens" utility | Option 2 (`Vec<i32>`) — simplest, most idiomatic, order-preserving |
| Feeding into a `for` loop / another adapter chain, no buffer needed | Option 3 (`impl Iterator`) |

For a rustlings-style exercise, Option 1 is the most pedagogically interesting because it forces you to confront *why* slices can't do arbitrary selection — and it's a nice bridge toward `Vec::retain`'s actual implementation, and later, `slice::sort_by`/partitioning algorithms, which use the exact same swap-based technique.

Want me to write this up as a full exercise/solution pair (with `#[cfg(test)]` blocks) for your workspace — maybe including both the mutating in-place version and the `Vec`-returning version so the contrast is explicit?
