## Intro

which of following two impl is more idiomatic and why ?

1.
```rust
impl From<&u16> for SaturatingU16 {
    fn from(value: &u16) -> Self {
        (*value).into()
    }
}
```


2.
```rust
impl From<&u8> for SaturatingU16 {
    fn from(value: &u8) -> Self {
        Self { value: *value as u16 }
    }
}
```

**#1 is the more idiomatic version.** The reasoning comes down to a core Rust convention: `From<&T>` impls should almost always delegate to the corresponding `From<T>` impl rather than reimplementing the conversion logic.

## Why #1 wins

```rust
struct SaturatingU16 {
    value: u16,
}

// The "base" conversion — single source of truth
impl From<u16> for SaturatingU16 {
    fn from(value: u16) -> Self {
        Self { value }
    }
}

// Reference variant just dereferences and reuses it
impl From<&u16> for SaturatingU16 {
    fn from(value: &u16) -> Self {
        (*value).into()
    }
}
```

`u16` is `Copy`, so dereferencing costs nothing (`*value` is a cheap register copy, not a move-out-of-borrowed-content violation). Once you have an owned `u16`, calling `.into()` routes through the *existing* `From<u16> for SaturatingU16` impl. This means:

- **One place owns the conversion logic.** If the saturating/clamping behavior ever changes (e.g., you add validation, logging, or a different saturation policy), you fix it in exactly one `impl` block. Every reference-based conversion inherits the fix automatically.
- **It matches standard library convention.** The whole standard library follows this pattern — e.g. `impl From<&str> for String` delegates to the same allocation path that `String::from` uses for owned data; `impl<T: Clone> From<&T> for T` (in some contexts) similarly just clones and reuses. Rust's culture strongly favors "thin wrapper delegates to canonical impl" over duplicated logic.
- **It's harder to accidentally drift.** Duplicated logic in two impls is a classic bug source — someone updates the owned-value impl and forgets the reference impl exists.

## Why #2 is the anti-pattern

```rust
impl From<&u8> for SaturatingU16 {
    fn from(value: &u8) -> Self {
        Self { value: *value as u16 }
    }
}
```

This reaches directly into the struct's field (`Self { value: ... }`) and reimplements the cast logic, completely bypassing whatever `From<u8> for SaturatingU16` does. Two problems:

1. **Duplication** — if a `From<u8>` impl exists elsewhere with the "real" conversion logic (which for a type literally named `SaturatingU16` might someday include actual saturating arithmetic, not just a widening cast), this impl silently diverges from it.
2. **Field coupling** — this only compiles because you're in the same module as the private field. It doesn't scale — if the struct grows more fields or invariants, every "shortcut" impl like this has to be manually kept in sync.

## The idiomatic version of #2

```rust
impl From<u8> for SaturatingU16 {
    fn from(value: u8) -> Self {
        Self { value: value as u16 }
    }
}

impl From<&u8> for SaturatingU16 {
    fn from(value: &u8) -> Self {
        (*value).into()   // delegate, same as the u16 case
    }
}
```

## The general mental model

Think of it as a **conversion graph with one canonical edge per type pair**. `From<&T>` isn't really "a different conversion" — it's just "dereference, then use the conversion that already exists." Writing it any other way means you now have two independent implementations of what should be one idea, and the compiler won't warn you when they disagree.

A good gut-check: **if your `From<&T>` impl body doesn't contain `.into()` or an explicit call into the owned-value impl, ask why it needs its own logic at all.**

### Next step to deepen this

Look at how this scales when the "canonical" impl isn't infallible — e.g. `TryFrom<u32> for SaturatingU16` for a genuinely saturating (clamping) conversion, plus `TryFrom<&u32>` delegating the same way. That's where you'll see the delegation pattern combined with `?` and error types, which is the next natural rung up from what you're doing here.