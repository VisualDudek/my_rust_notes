# Intro

Po co implementować ten sam kod dla różnych typów, jak zastosować DRY w tym przypadku?
```rust
trait IsEven {
    fn is_even(&self) -> bool;
}

impl IsEven for u32 {
    fn is_even(&self) -> bool {
        self % 2 == 0
    }
}

impl IsEven for i32 {
    fn is_even(&self) -> bool {
        self % 2 == 0
    }
}
```


## Generic version (std only, no macro, no extra crate)

```rust
use std::ops::Rem;

trait IsEven {
    fn is_even(&self) -> bool;
}

impl<T> IsEven for T
where
    T: Rem<Output = T> + PartialEq + From<u8> + Copy,
{
    fn is_even(&self) -> bool {
        *self % T::from(2) == T::from(0)
    }
}

fn main() {
    println!("{}", 4u32.is_even()); // true
    println!("{}", 5i32.is_even()); // false
}
```

This is a **blanket impl** — one `impl<T> IsEven for T` covers every type that satisfies the bounds, instead of writing `impl IsEven for u32 { ... }` and `impl IsEven for i32 { ... }` by hand. `u32` and `i32` both implement `Rem`, `PartialEq`, `Copy`, and `From<u8>`, so they're automatically covered — as is `i64`, `u8`, `i128`, etc., with zero extra code.

Why `From<u8>` instead of a literal `2`: same issue as last time — inside a generic function, `2` has no inherent type until it's unified with `T`, and there's no bound that lets you write a bare numeric literal for an arbitrary `T`. `From<u8>` is the idiomatic way to manufacture small constants generically, since every integer primitive implements `From<u8>` losslessly.

## Simpler alternative: macro instead of generics

If you don't want trait-bound gymnastics, a declarative macro is very idiomatic for "same body, different concrete types":

```rust
trait IsEven {
    fn is_even(&self) -> bool;
}

macro_rules! impl_is_even {
    ($($t:ty),*) => {
        $(
            impl IsEven for $t {
                fn is_even(&self) -> bool {
                    self % 2 == 0
                }
            }
        )*
    };
}

impl_is_even!(u8, u16, u32, u64, u128, i8, i16, i32, i64, i128, isize, usize);
```

This expands at compile time to exactly the repetitive impls you'd otherwise hand-write — no runtime cost, no trait-bound complexity, and it scales to all 12 integer types in one line. This is in fact how the standard library implements many traits (like `Add`, `PartialEq`) across the primitive types internally.

## Which to reach for

| Situation | Choice |
|---|---|
| Logic naturally generalizes, might take other bounds later | Blanket generic impl |
| Just want to stamp out the same impl across many concrete types, no genuine generic logic | `macro_rules!` |

For something as simple as `is_even`, I'd lean macro — the generic version's `From<u8>` bound-juggling is overkill for a `% 2 == 0` check. Save the generic/trait-bound approach for logic that actually benefits from being written once and reasoned about abstractly.

**Next step worth exploring**: try adding a *default* method to `IsEven` — e.g. `fn is_odd(&self) -> bool { !self.is_even() }` — so implementors only need to define `is_even` and get `is_odd` for free. That's the "default fn in trait" mechanic you asked about, applied directly to this trait.