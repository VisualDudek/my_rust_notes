## Intro

Jakim cudem to działa? `trim` signature: `fn trim(&self) -> &str`, a `self.title` ma typ `String`.
```rust
pub struct Ticket {
    title: String,
    description: String,
    status: String,
}

impl Ticket {
    pub fn title(&self) -> &str {
        self.title.trim()
    }
}
```
Good catch — this is exactly the **autoderef/autoref in method resolution** mechanism, and it's worth tracing precisely because it looks like a type mismatch at first glance.

## The core fact

`String` does **not** have a `trim` method. `trim` is defined only in `impl str`:

```rust
impl str {
    pub fn trim(&self) -> &str { ... }
}
```

So `self.title.trim()` where `self.title: String` *shouldn't* type-check if Rust required an exact match. It works because method-call syntax (`receiver.method()`) doesn't do exact matching — it does a **search**.

## The method resolution algorithm

Given `self.title.trim()`, the compiler builds a list of candidate receiver types by repeatedly dereferencing the base type, and at *each* step also considers `&T` and `&mut T`:

```
Step 0: String
Step 0a: &String
Step 0b: &mut String
Step 1: deref String -> str        (via impl Deref<Target = str> for String)
Step 1a: &str
Step 1b: &mut str
```

At each step, the compiler checks: "does this type have an inherent or trait method called `trim`?"

- `String` — no.
- `&String` — no.
- `&mut String` — no.
- `str` (after one deref) — yes! `impl str { fn trim(&self) }` exists.

Since `trim` takes `&self`, the compiler needs a `&str`, so it stops at "take `&` of the deref'd type" — step 1a — and that's the match.

## What the desugared call actually looks like

```rust
self.title.trim()
// desugars to:
str::trim(&*self.title)
```

Breaking that down:
- `*self.title` — dereferences `String` to `str` (this only compiles because of `impl Deref<Target = str> for String`, i.e. `String`'s deref target is `str`)
- `&*self.title` — takes a reference to that, producing `&str`
- `str::trim(&str) -> &str` — now the signature matches exactly

So no cloning, no allocation — just a pointer reinterpretation. `String` is `{ ptr, len, capacity }` on the heap; `&str` is `{ ptr, len }` (a fat pointer). Deref just narrows the view.

## Why this is *not* the same as function-argument deref coercion

You've already got deref coercion filed away for things like this:

```rust
fn print_it(s: &str) { println!("{s}"); }
let owned = String::from("hi");
print_it(&owned); // &String coerces to &str at the call boundary
```

That's coercion at a **typed position** (function parameter expects `&str`, you supplied `&String`, compiler inserts a deref automatically).

Method resolution is a *different* mechanism that happens to lean on the same `Deref` trait: instead of coercing a value to fit an expected type, it **searches outward** through deref steps to find *any* type that defines the method being called. The trigger is different (method lookup vs. argument-type mismatch) even though both ultimately call on `impl Deref`.

## Try it yourself to see the boundary

```rust
fn takes_str(s: &str) -> usize { s.len() }

fn main() {
    let s = String::from("hello");
    
    // Method resolution: works via autoderef search
    println!("{}", s.trim());
    
    // Function call: works via deref coercion
    println!("{}", takes_str(&s));
    
    // But this FAILS — no method resolution search at a plain `let` binding:
    // let x: str = *s; // error: `str` is unsized, can't be a local variable
}
```

That last commented line is a good follow-up experiment: it shows *why* method resolution stops at `&str` and never actually produces a bare, owned `str` — `str` is a DST (you've already got this from your string/DST notes), so the deref chain can only ever be *used through a reference*, never bound as a value. The `&` in "autoref" isn't optional set dressing — it's structurally required by `str` being unsized.

**Natural next step given where you are:** this exact mechanism (search-then-autoref, bottoming out at a DST) is precisely what makes custom smart pointers ergonomic once you implement `Deref` yourself — which lines up with "`Deref`/`DerefMut` on custom smart pointers" on your list. Want to trace through a toy `MyBox<T>` example and watch the same method-resolution search happen for a type you define?
