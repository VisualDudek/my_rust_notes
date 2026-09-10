## Intro

That's a solid starting mental model, but let's sharpen it a bit because "borrow out of" could accidentally cover too much ground (e.g. it might make you think `&Ticket` -> `&str` is possible via some field access magic — it's not, only through explicit `Deref` impls).

**More precise mental model: "here's how to treat this type as if it were a pointer to something else."**

`Deref` is fundamentally the trait behind **smart pointer** behavior. The signature is:

```rust
trait Deref {
    type Target: ?Sized;
    fn deref(&self) -> &Self::Target;
}
```

It says: "I am a pointer-like wrapper around a `Target`, and here's how to get a plain reference to what I'm wrapping, without giving up ownership of the wrapper itself."

Examples of the pattern:

| Type | Target | What it "is a pointer to" |
|---|---|---|
| `String` | `str` | owned buffer → borrowed view |
| `Vec<T>` | `[T]` | owned buffer → borrowed slice |
| `Box<T>` | `T` | heap allocation → the value itself |
| `Rc<T>` / `Arc<T>` | `T` | ref-counted allocation → the value itself |
| `MutexGuard<T>` | `T` | lock guard → the protected value |

Notice the pattern: in every case, the type is a **wrapper that owns or guards something**, and `Deref` is how you get a **plain, ordinary reference** to the thing inside — stripping away the ownership/allocation/locking machinery.

**What `Deref` is *not*:**

- It's not "how to borrow any field out of a struct." You can't write `Deref` to make `&Ticket` auto-convert to `&str` just because `Ticket` has a `title: String` field — that would be ambiguous and un-idiomatic (which field would it be?). `Deref` is meant for types that conceptually *are* a single wrapped value, not types with multiple unrelated fields. Implementing `Deref` on a struct just to save typing `.title` is considered an anti-pattern in Rust (the docs specifically warn against this).
- It's not just about return types — deref coercion also fires on method calls (`my_string.len()` works because `String` derefs to `str` and `len()` is defined on `str`... actually `String` has its own `len`, but the classic example is calling `&str` methods on a `String` directly) and on function arguments (`fn foo(s: &str)` accepts a `&String` argument via coercion).

**A cleaner one-liner**: `Deref` means "I am a smart pointer; here's the plain reference you get when you follow me." The compiler's job (deref coercion) is just deciding *when* to automatically insert that "follow the pointer" step so you don't have to write `.deref()` everywhere.