## Intro

## Note: `&x` vs `&*x`

**Rule of thumb:** write `&x`. Reach for `&*x` only when you need to force something coercion won't reach on its own.

**`&x` (let coercion do the work)** — the compiler inserts the `deref()` call for you, but *only* at specific sites: function-call args, `let` bindings with an explicit target type, method receivers, return position.

```rust
fn takes_str(s: &str) {}
let owned = String::from("hi");
takes_str(&owned);           // &String -> &str, coercion fires here
```

**`&*x` (explicit deref, then re-borrow)** — needed when the site isn't one of the coercion points, so nothing will insert the deref automatically. Common cases:

```rust
// 1. Generic context — T is unknown to the compiler, no coercion target to aim at
fn generic<T: AsRef<str>>(x: T) { let s: &str = x.as_ref(); }
// vs. manually forcing a concrete deref chain:
let boxed: Box<String> = Box::new(String::from("hi"));
let s: &str = &*boxed;       // Box<String> -deref-> String -deref-> str, chained explicitly
                              // (plain &boxed would coerce all the way too here — but
                              //  the chain becomes explicit-only once ambiguity or a
                              //  generic bound is in the way)

// 2. Match/pattern position — coercion doesn't apply inside patterns
match &*owned {
    "hi" => {}                // need &str to match a &str literal pattern
    _ => {}
}

// 3. Disambiguating which Deref impl / method to call when multiple are in scope
let s = &*owned;              // explicit: "I mean str, via Deref, not some other candidate"
```

> Match/pattern position doesn't trigger coercion, so you need `&*x` there.

**Mental anchor:** `&*x` is the *desugared* form of what coercion does silently — same runtime effect, but written by hand because the compiler needs a nudge (no coercion site, generic bound, or pattern context) rather than a hint (concrete `let`/arg type).

---

Yes — but the mechanism is worth being precise about, since `*` itself and "coercion" are two different things layered on top of each other.

**The trait**

```rust
impl Deref for String {
    type Target = str;
    fn deref(&self) -> &str { self.as_str() }
}
```

`String` doesn't *become* `str` — `str` is a DST (unsized, no known size at compile time), so you can never have a bare `str` value, only `&str` (fat pointer: data ptr + len). `Deref::deref` takes `&self` and returns `&Self::Target`, i.e. `&str`.

**What `*` actually does**

`*expr` calls `deref()` and then... you almost always immediately re-borrow it, because you can't hold an unsized value by itself:

```rust
let s: String = String::from("hello");
let r: &str = &*s; // deref() -> str (place expression), then & re-borrows it as &str
```

This `&*x` pattern is the *explicit* desugared form. You'll see it when you want to be unambiguous, or when coercion doesn't kick in (e.g. inside a generic context, or matching on the target type explicitly).

**Coercion is what makes you rarely need `*` at all**

Per your `learnings.md` note — coercion applies at specific sites: function-call arguments, `let` bindings with an explicit type, method-call receivers, return position. So:

```rust
fn takes_str(s: &str) { println!("{s}"); }

let owned = String::from("hello");
takes_str(&owned); // &String -> &str, coercion inserts the deref() call for you
```

Here you never wrote `*` — the compiler saw `&String` where `&str` was expected, found `String: Deref<Target = str>`, and inserted the equivalent of `&*owned` for you at that call site.

**Where `*` alone (without `&`) is meaningful**

If you own the `String` and want to move/operate on what it derefs to by value, that's impossible for `str` (unsized) — this is exactly why `Deref` returns `&Target`, not `Target`. Contrast with `Box<T>`, where `T: Sized`, so `*boxed_t` is a valid place expression you can move out of or assign to:

```rust
let b: Box<i32> = Box::new(5);
let n: i32 = *b; // moves the i32 out — fine, i32 is Sized
```

**So, to directly answer "masquerade":**

| Form | What happens |
|---|---|
| `&owned_string` where `&str` expected | deref **coercion**, compiler-inserted, no `*` in your source |
| `&*owned_string` | explicit deref call + re-borrow, same result, written out by hand |
| `*owned_string` alone | doesn't type-check as a standalone expression for unsized targets — you can't materialize a bare `str` value |
| `owned_string.some_str_method()` | **autoderef** during method resolution, a distinct mechanism from coercion — walks `String -> str` looking for the method |

Next natural thread: `DerefMut` and why it's the mechanism behind `Vec<T>` → `&mut [T]` coercion too, or how `Cow<str>` uses `Deref` to let you write generic code over "borrowed or owned string" uniformly.