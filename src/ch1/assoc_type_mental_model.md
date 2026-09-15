## Intro

Yes — that's exactly the right mental model, and it's the key thing that distinguishes associated types from generic type parameters.

**Associated type: one implementation per type**

```rust
trait Container {
    type Item;
    fn get(&self) -> Self::Item;
}

struct Wrapper(i32);

impl Container for Wrapper {
    type Item = i32;
    fn get(&self) -> i32 { self.0 }
}

// This would NOT compile — conflicting implementation:
// impl Container for Wrapper {
//     type Item = String;
//     fn get(&self) -> String { "x".into() }
// }
```

Once you write `impl Container for Wrapper`, the compiler locks in `Item = i32` for `Wrapper`, forever. You cannot have a second `impl Container for Wrapper` with a different `Item`. This is why you can write `Container::Item` or `<Wrapper as Container>::Item` and get a single, unambiguous type back — the compiler doesn't need any extra hint, because there's only one answer.

**Generic type parameter: many implementations per type**

```rust
trait Convert<T> {
    fn convert(&self) -> T;
}

struct Wrapper(i32);

impl Convert<i32> for Wrapper {
    fn convert(&self) -> i32 { self.0 }
}

impl Convert<String> for Wrapper {
    fn convert(&self) -> String { self.0.to_string() }
}
```

This compiles fine — `Wrapper` implements `Convert<i32>` *and* `Convert<String>` simultaneously, because `T` is a parameter of the trait itself, not something fixed by the `impl`. Here you often need turbofish or type annotations at the call site (`wrapper.convert::<i32>()` or letting inference pick from context) because there genuinely are multiple valid answers.

**The rule of thumb**

- Associated type → "this type has *the* Item type" (a functional/output relationship — one input, one output)
- Generic parameter → "this type can relate to *many* different types" (a many-to-many relationship)

This is exactly why `Iterator` uses an associated type (`Iterator::Item` — a given iterator produces one kind of item) while something like `From<T>`/`Into<T>` uses generic parameters (a type can convert *from* many different source types).

One subtlety worth internalizing alongside this: the "one type, one impl" rule applies per concrete type, not per generic type. `impl<T> Container for Vec<T> { type Item = T; }` is still just one impl — the associated type varies with `T`, but for any *specific* `Vec<i32>` it's still pinned to exactly one `Item = i32`. The coherence/orphan rules that prevent conflicting impls in general are exactly what's protecting this uniqueness guarantee.