## Intro

Jake znaczenie ma `Self` z dużej litery?
```rust
pub trait PartialEq {
    fn eq(&self, other: &Self) -> bool;
    fn ne(&self, other: &Self) -> bool {
        !self.eq(other)
    }
}
```

Yes — `Self` (capital) and `self` (lowercase) are two completely different things.

- **`self`** (lowercase) — the receiver parameter. Shorthand for `self: Self`, `&self` for `self: &Self`, `&mut self` for `self: &mut Self`. It's a *value*.
- **`Self`** (capital) — a type-level alias meaning "whatever concrete type this trait/impl block is currently being applied to." It's a *type*, resolved at the `impl` site, not at the trait definition site.

So in your example:

```rust
pub trait PartialEq {
    fn eq(&self, other: &Self) -> bool;
    fn ne(&self, other: &Self) -> bool {
        !self.eq(other)
    }
}
```

`Self` isn't known when the trait is *defined* — it's a placeholder. It only gets substituted with a concrete type when someone writes an `impl`:

```rust
struct Point { x: i32, y: i32 }

impl PartialEq for Point {
    fn eq(&self, other: &Self) -> bool {
        // here Self == Point, mechanically identical to:
        // fn eq(&self, other: &Point) -> bool
        self.x == other.x && self.y == other.y
    }
}
```

The compiler performs a literal substitution: everywhere `Self` appears in the trait's method signatures, drop in the implementing type. This is why `eq`'s signature desugars to `fn eq(self: &Point, other: &Point) -> bool` for the `Point` impl.

**Why this matters mechanically — it's what makes `other: &Self` type-safe by construction:**

Because `Self` is resolved per-impl, `PartialEq for Point` can *only* ever compare a `Point` to a `Point`. You cannot call `point.eq(&5)` — there's no impl where `Self` unifies to both `Point` and `i32` simultaneously. This is a compile-time guarantee, not a runtime check — it's precisely why `1 == "a"` doesn't type-check in Rust (real `PartialEq` is `PartialEq<Rhs = Self>`, generic over the RHS, but defaults to `Self`).

**Other places `Self` shows up:**

```rust
struct Point { x: i32, y: i32 }

impl Point {
    // Self in return position — constructor pattern
    fn origin() -> Self {
        Self { x: 0, y: 0 }   // Self { .. } is shorthand for Point { .. }
    }

    // Self as a type in a method body
    fn translate(&self, dx: i32, dy: i32) -> Self {
        Self { x: self.x + dx, y: self.y + dy }
    }
}

enum Direction { North, South }

impl Direction {
    fn opposite(&self) -> Self {
        match self {
            Self::North => Self::South,  // Self::Variant, not just Variant
            Self::South => Self::North,
        }
    }
}
```

Using `Self` instead of spelling out `Point` everywhere is not just DRY — if you rename the struct, or if you're inside a `#[derive]`-adjacent macro context, `Self` stays correct without edits.

**One sharp edge worth knowing** since you're deep in traits/generics: `Self` in *argument or return position by value* (`fn foo(self) -> Self`) is part of why some traits aren't object-safe (can't build a `dyn Trait` from them) — `dyn Trait` erases the concrete type, but `Self` requires knowing the concrete size/type at the call site. `PartialEq` itself is not object-safe for exactly this reason (`other: &Self`) — you'll never see `dyn PartialEq`.

Natural next step given where you are: look at `PartialEq<Rhs>` vs plain `PartialEq` (the `Rhs = Self` default type parameter) — it explains how things like `String: PartialEq<str>` exist despite the "same-type" constraint above.

## Czy `Self` jest type aliasem?

Close, but "just a type alias" undersells one important nuance — let's pin down exactly where the analogy holds and where it breaks.

**Where it behaves exactly like a type alias:**

```rust
struct Point { x: i32, y: i32 }

impl Point {
    fn origin() -> Self {        // reads identically to:
        Self { x: 0, y: 0 }
    }
}

// mechanically, inside this impl block, it's as if you wrote:
type __ThisAlias = Point;
```

For a non-generic `impl`, this is a completely accurate mental model. `Self` is substituted textually with `Point` everywhere it appears in that block.

**Where it stops being "just" an alias — generic impls:**

A real `type` alias is a fixed, named type you declare once. `Self` isn't fixed at the trait/impl *definition* — it's resolved per monomorphization when the impl is generic:

```rust
struct Wrapper<T> { value: T }

impl<T: Clone> Wrapper<T> {
    fn duplicate(&self) -> Self {
        // Self here is Wrapper<T>, NOT Wrapper<some-single-concrete-type>
        Self { value: self.value.clone() }
    }
}
```

For `Wrapper<i32>`, `Self` means `Wrapper<i32>`. For `Wrapper<String>`, `Self` means `Wrapper<String>`. It's not one alias — it's a placeholder that re-resolves per instantiation, carrying whatever generic parameters and lifetimes the `impl` block bound. A `type` alias can't do this kind of context-dependent re-binding; you'd have to write `type WrapperAlias<T> = Wrapper<T>;` and it'd still just be a generic alias, not something whose meaning shifts based on "which impl block am I standing in."

**Where it *really* stops being an alias — trait definitions:**

This is the sharper distinction, and it's the case you started with:

```rust
trait Shape {
    fn scaled(&self, factor: f64) -> Self;
}
```

At the point this trait is *defined*, there is no type for `Self` to alias to. `type` aliases must resolve to something concrete (or a generic parameter in scope) at declaration time. `Self` here is more like an implicit generic parameter of the trait — every method is effectively `fn scaled<Self: Shape>(&self, factor: f64) -> Self` bound to whatever the eventual implementor is. It only becomes a concrete alias at the `impl` site, not at the `trait` site.

So the precise statement:

- **In a non-generic `impl` block** — yes, functionally a type alias for the concrete type.
- **In a generic `impl` block** — an alias for the *current instantiation*, `Self` = `Wrapper<T>` with `T` still abstract.
- **In a `trait` definition** — not an alias at all yet; it's a placeholder/implicit type parameter with no referent until something implements the trait.

This is also exactly why `Self`-returning methods make a trait non-object-safe (as mentioned before) — `dyn Trait` needs `Self` resolved to one concrete type at the `impl` site, but a trait object erases which impl you're talking to, so there's nothing left to substitute.

Next natural thread: this connects directly to `impl Trait for T` vs. blanket impls like `impl<T: Display> ToString for T` — in the blanket case, `Self` = `T`, and it's a good exercise in tracing how far the "current instantiation" resolution actually reaches.