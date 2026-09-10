## Intro

Jak `&String` staje się `&str`?
```rust
pub struct Ticket {
    title: String,
    description: String,
    status: String,
}
```
No compiler magic exactly — it's a specific, well-defined mechanism called **deref coercion**.

**The chain of types**

`self.title` is a `String`. Taking a reference gives you `&String`. But the function signature says the return type is `&str`. So Rust needs to go from `&String` to `&str`.

This works because `String` implements the `Deref` trait:

```rust
impl Deref for String {
    type Target = str;
    fn deref(&self) -> &str { ... }
}
```

`Deref` says "here's how to borrow a `str` view out of a `String`." Under the hood, a `String` is just a `Vec<u8>` (pointer, length, capacity) that's guaranteed to hold valid UTF-8. A `str` is just a "view" over bytes known to be UTF-8 — it has no ownership, no capacity, just a pointer + length. So `String`'s `deref()` just hands back a pointer to its buffer and its length, reinterpreted as `&str`. No copying, no allocation.

**Where the "coercion" happens**

Rust applies **deref coercion** at specific points — function return values, function arguments, method calls — where it will automatically insert a call to `.deref()` if the types don't match but a `Deref` impl bridges them.

So `&self.title` (type `&String`) gets coerced:

```rust
&self.title           // &String
    .deref()           // inserted automatically → &str
```

You could write it explicitly and it'd be identical:

```rust
pub fn title(&self) -> &str {
    self.title.deref()
    // or: self.title.as_str()
}
```

`as_str()` is actually the idiomatic explicit method, and it does the exact same thing `deref()` does — it's just a directly-named method instead of relying on trait-based coercion.

**Why this design exists**

`&str` is the "read-only borrowed string" type, and `String` is the "owned, growable string" type. Any function that just wants to *look at* a string shouldn't care whether the caller has a `String`, a `&str`, or a string literal — so Rust lets `&String` silently become `&str` wherever a `&str` is expected. That's why `title()` returning `&str` instead of `&String` is the idiomatic choice: it's the more general, more flexible type to hand back to callers, and they lose nothing (they can't mutate it anyway since it's behind `&`).

**One more subtlety**: this is a *reference* conversion, not a value conversion. `self.title` itself is never moved or consumed — `title()` borrows it for the lifetime of `&self`, which is why the signature is `fn title(&self) -> &str` and not `fn title(self) -> &str`. The returned `&str`'s lifetime is tied to `&self`'s lifetime (elided but present), so the caller can't hold onto that `&str` longer than the `Ticket` it came from.