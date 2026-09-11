# Rust `Power` Trait Notes (Associated Type vs Generics)

## Intro

In this exercise, we define a `Power` trait for exponentiation:

- Base: `self` (e.g. `u32`)
- Exponent: potentially different types (`u16`, `u32`, `&u32`)
- Output: result type of exponentiation

A common design is:

```rust
pub trait Power<Exponent = Self> {
    type Output;
    fn power(&self, n: Exponent) -> Self::Output;
}
```

This design separates:
- input exponent type (`Exponent`)
- output type (`Output`)

---

## Working solution (with associated type)

```rust
pub trait Power<Exponent = Self> {
    type Output;
    fn power(&self, n: Exponent) -> Self::Output;
}

impl Power<u16> for u32 {
    type Output = u32;
    fn power(&self, n: u16) -> Self::Output {
        self.pow(n.into())
    }
}

impl Power<u32> for u32 {
    type Output = u32;
    fn power(&self, n: u32) -> Self::Output {
        self.pow(n)
    }
}

impl Power<&u32> for u32 {
    type Output = u32;
    fn power(&self, n: &u32) -> Self::Output {
        self.pow(*n)
    }
}
```

---

## Can it be done **without** associated type?

Yes.

If all implementations return the same type (`u32`), you can define:

```rust
trait Power<T = Self> {
    fn power(&self, n: T) -> u32;
}
```

### Why this is okay
- simpler trait definition
- easier to read for beginners
- sufficient if output is always `u32`

### Downside
- less future-proof
- you cannot vary output type per implementation
- output type is hardcoded forever
- not reusable for types where exponentiation should return something else

---

## Why associated type (`type Output`) is useful

Associated type allows each implementation to choose its own return type.

```rust
trait Power<T = Self> {
    type Output;
    fn power(&self, n: T) -> Self::Output;
}
```

### Benefits
- more expressive API design
- supports heterogeneous outputs
- scales better when trait is reused across many types

### Example motivation
You might want one implementation to return `u32`, another to return `f64`, etc.  
With fixed `-> u32` or `-> Self`, that is impossible.

---

## Returning `-> Self` in trait definition

Alternative:

```rust
trait Power<T = Self> {
    fn power(&self, n: T) -> Self;
}
```

### Good
- concise
- works when exponentiation always returns same type as receiver

### Downside
- also restrictive
- cannot represent valid cases where result type differs from `Self`

So `-> Self` is usually **more restrictive** than `type Output`.

---

## What `T = Self` means

`T = Self` sets a **default generic parameter**.

```rust
trait Power<T = Self> { ... }
```

This means:
- `impl Power for u32` is treated as `impl Power<u32> for u32`
- you can still override it:
  - `impl Power<u16> for u32`
  - `impl Power<&u32> for u32`

### Why it helps
- less typing for common case
- keeps flexibility for special exponent types

Without `= Self`, every impl must explicitly name `T`.

---

## Why `Self::Output` and not just `Output`?

`Output` is an associated type tied to the implementing type (`Self`), so it must be qualified:

```rust
fn power(&self, n: T) -> Self::Output;
```

`Output` alone is not in scope as a standalone type name.  
`Self::Output` tells Rust: “use the `Output` chosen by this implementation.”

(When disambiguation is needed, you can use fully qualified form:
`<Self as Power<T>>::Output`.)

---

## Practical guidance

- Use **fixed return type** (`u32`) when domain is narrow and stable.
- Use `-> Self` when output is always exactly receiver type.
- Use **associated type** when you want a reusable, extensible trait design.
- Use `T = Self` when the common exponent type is `Self`, but you still want overrides.

---

## Final takeaway

For learning and this exercise, both are valid:

- Simpler:
  ```rust
  trait Power<T = Self> {
      fn power(&self, n: T) -> u32;
  }
  ```

- More extensible:
  ```rust
  trait Power<T = Self> {
      type Output;
      fn power(&self, n: T) -> Self::Output;
  }
  ```

Choose based on whether you optimize for **simplicity now** or **flexibility later**.