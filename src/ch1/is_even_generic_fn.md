## Intro

Why following generic fn. wont compile?

```rust
fn g_is_even<T>(n: T) -> bool
where 
    T: Rem 
{
    n % 2 == 0
}
```

Two separate holes in that signature, and they compound:

**1. `Rem`'s associated `Output` has no default.** The trait is:

```rust
pub trait Rem<Rhs = Self> {
    type Output;
    fn rem(self, rhs: Rhs) -> Self::Output;
}
```

Only `Rhs` gets a default (`Self`) — that's a *default generic type parameter*, a stable feature. `Output` is a plain associated type with no default; Rust doesn't have stable "default associated types." So `T: Rem` desugars to `T: Rem<T, Output = ??>` — the compiler knows `n % 2` produces *some* `T::Output`, but has zero information about what that type is or whether it implements `PartialEq<i32>`. That's why `== 0` fails.

**2. The literal `2` has no type to infer against.** Since `Rhs` defaults to `Self` = `T`, the compiler needs `2: T`. For a fully generic, opaque `T`, there's no mechanism to conjure a literal into it — integer-literal inference only resolves against concrete numeric types or an explicit suffix, not an arbitrary type parameter.

Fix both by closing the associated type and giving yourself a real way to construct `2` and `0` of type `T`:

```rust
use std::ops::Rem;

fn g_is_even<T>(n: T) -> bool
where
    T: Rem<Output = T> + PartialEq + From<u8>,
{
    n % T::from(2) == T::from(0)
}
```

- `Rem<Output = T>` pins the associated type, so `n % T::from(2) : T`.
- `PartialEq` (default `Rhs = Self`) lets you compare `T == T`. Note `==` desugars to `PartialEq::eq(&a, &b)` — it borrows, doesn't move — so you don't need `Copy` here even though `n` gets consumed by `Rem::rem(self, ...)`.
- `From<u8>` replaces the bare literal with an actual generic-safe constructor. `u8` is a reasonable minimal bound since it's implemented for all primitive int and float types.

That compiles for `i32`, `u64`, `f64`, etc.

**The idiomatic escape hatch:** hand-rolling numeric bounds like this every time is exactly the pain `num-traits` exists to solve:

```toml
[dependencies]
num-traits = "0.2"
```

```rust
use num_traits::PrimInt;

fn is_even<T: PrimInt>(n: T) -> bool {
    n & T::one() == T::zero() // bitwise, integer-only, no division
}
```

`PrimInt` bundles `Zero`/`One`/bitwise ops/etc. so you get `T::one()`/`T::zero()` for free instead of threading `From<u8>` through every function, and the bitmask form is the idiomatic even/odd check anyway — no `Rem` needed, no divide instruction generated.

Next natural step given where you are: this is a good on-ramp into `TryFrom`/`TryInto` (already on your list) — try writing the same function bounded by `TryFrom<i32>` instead of `From<u8>` and see why you suddenly need to handle the `Result` from the conversion, which is the real reason `From<u8>` was the pragmatic choice above.

