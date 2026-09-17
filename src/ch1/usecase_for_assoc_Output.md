## Into

Good question — let's make it concrete instead of abstract. There are two genuinely distinct benefits, and I'll show code that's impossible (or much uglier) without `Output` for each.

## Benefit 1: different impls can return *different* types

If you want `power` to sometimes widen the result (e.g. to avoid overflow) or otherwise return something other than `Self`, you need a way for each `impl` to say what its own result type is. A fixed return type in the trait signature can't express that.

```rust
trait Power<T = Self> {
    type Output;
    fn power(self, exp: T) -> Self::Output;
}

// u8 is narrow enough that even small powers overflow it fast,
// so this impl widens the result to u32 to avoid that.
impl Power<u8> for u8 {
    type Output = u32;
    fn power(self, exp: u8) -> u32 {
        (self as u32).pow(exp as u32)
    }
}

// i64 stays i64 — no widening needed here.
impl Power<u32> for i64 {
    type Output = i64;
    fn power(self, exp: u32) -> i64 {
        self.pow(exp)
    }
}
```

```rust
let a: u32 = 200u8.power(3u8);   // Output = u32, would've overflowed as u8
let b: i64 = 5i64.power(3u32);   // Output = i64
```

Without `Output`, the trait would have to hardcode one return type (say `-> u32`), and then the `i64` impl simply couldn't exist — you can't implement `fn power(self, exp: u32) -> u32` for `i64` when `self: i64`, that's a type error. `Output` is exactly the mechanism that lets each impl's result type be "whatever that impl needs."

## Benefit 2: writing *generic* code against the trait

This is the one that's truly impossible without an associated type, not just less convenient. Suppose you want to write a function that works for *any* type implementing `Power`, without knowing which concrete type at compile time:

```rust
fn power_and_print<A, T>(base: A, exp: T) -> A::Output
where
    A: Power<T>,
    A::Output: std::fmt::Display,
{
    let result = base.power(exp);
    println!("result = {result}");
    result
}
```

Here `A::Output` is how the function *names* "whatever `power` returns for this particular `A`/`T` pairing" — it has to refer to it somehow to write the return type, and there is no other syntax available to do that. If `Output` weren't associated to the trait, this generic function couldn't be written at all, because the return type varies per-`A` and Rust needs a name for it right there in the signature.

Try to write the equivalent without `Output` and you'll find yourself stuck immediately — you'd need something like `fn power_and_print<A: Power, R>(base: A, exp: A) -> R` with an extra generic parameter `R` that the caller has to specify and that the trait can't constrain to "the actual result type of this impl." That's strictly worse (unconstrained, callers must annotate, no compiler-checked link between the impl and the return type) — it's not really a substitute, just a broken version of the same idea.

**So the rule of thumb from before still holds** for your original three `u32` impls (skip `Output`, it added nothing) — but as soon as either of these two things becomes true — impls return genuinely different types, or you want to write code generic over the trait — `Output` stops being optional and becomes the only way to express it.