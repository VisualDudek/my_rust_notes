> why do i need `.iter()` method if I have implement IntoIterator Trait over &T ? why have both? and if so should `.iter()` be implement just by delegate `.into_iter()` over reference ?

In Rust, you technically do **not** need `.iter()` for the compiler to work, but idiomatic Rust provides both for ergonomics, API discovery, and method-chaining clarity.

---

### Why Have Both?

#### 1. Method Chaining vs. Explicit Referencing

If you only have `IntoIterator for &T`, calling it as a method requires an explicit reference:

```rust
// Without .iter(), you must write:
(&my_vec).into_iter().map(...);

// Or call the trait method fully qualified:
IntoIterator::into_iter(&my_vec).map(...);

// With .iter(), autoref handles it cleanly:
my_vec.iter().map(...);

```

Because `into_iter(self)` takes `self` by value, calling `my_vec.into_iter()` on a value of type `Vec<T>` consumes the collection. It will **not** automatically borrow `&my_vec`—it invokes `IntoIterator for Vec<T>`. Providing `.iter(&self)` allows method-call syntax (`my_vec.iter()`) to borrow automatically without moving ownership.

#### 2. Discoverability & Rust Idioms

`IntoIterator` is primarily designed for generic bounds (`where I: IntoIterator`) and powering `for` loops:

```rust
for item in &my_collection { /* ... */ } // uses IntoIterator for &T

```

`IntoIterator` is not in the prelude in standard discovery patterns, whereas `.iter()` and `.iter_mut()` are convention across standard library collections (`Vec`, `HashMap`, slices, etc.). Developers and IDE autocomplete expect `.iter()` on collection types.

---

### Should `.iter()` Delegate to `IntoIterator`?

**Yes.** In fact, delegating to `IntoIterator::into_iter` (or vice versa) is the recommended standard library convention.

Depending on your preference, there are two standard patterns:

#### Pattern A: Delegate `.iter()` to `IntoIterator`

```rust
pub struct MyCollection<T> {
    data: Vec<T>,
}

impl<'a, T> IntoIterator for &'a MyCollection<T> {
    type Item = &'a T;
    type IntoIter = std::slice::Iter<'a, T>;

    fn into_iter(self) -> Self::IntoIter {
        self.data.iter()
    }
}

impl<T> MyCollection<T> {
    pub fn iter(&self) -> std::slice::Iter<'_, T> {
        self.into_iter()
    }
}

```

#### Pattern B: Implement `.iter()` and Delegate `IntoIterator` to it

This is how most `std` collections (like `Vec` and `HashMap`) are defined:

```rust
impl<T> MyCollection<T> {
    pub fn iter(&self) -> std::slice::Iter<'_, T> {
        self.data.iter()
    }
}

impl<'a, T> IntoIterator for &'a MyCollection<T> {
    type Item = &'a T;
    type IntoIter = std::slice::Iter<'a, T>;

    fn into_iter(self) -> Self::IntoIter {
        self.iter()
    }
}

```

Both patterns achieve zero runtime cost (compiles down to identical machine code). The standard practice is:

* Use `IntoIterator` for `for` loops and generic functions.
* Expose `.iter()` and `.iter_mut()` as inherent methods on `&self` and `&mut self` for ergonomics and chaining.