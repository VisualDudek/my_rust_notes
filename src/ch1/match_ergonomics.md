## Introduction

## Compact notes: `match self` / references / match ergonomics

### 1. `self` vs `&self` in `match self` / `match &self` (method taking `&self`)
- `self` param already has type `&Self`.
- `match self` → scrutinee `&Self`. Match ergonomics kicks in, bindings come out as references.
- `match &self` → scrutinee `&&Self`. Compiler peels through **both** layers, ends up in the same `Ref` binding mode. **Identical behavior** — the extra `&` is redundant. Clippy: `needless_borrow`.
- Only matters if you deliberately want a `&&Self` for something else (e.g. passing to another fn).

### 2. A field/projection is *not* automatically a reference, even behind `&self`
- `self.status` — even though reached via `self: &Ticket` — has **declared type `Status`**, not `&Status`. Reference-ness does not propagate upward through `.field` (or `v[0]`, or `*opt`, etc.) — you must ask for it explicitly.
- `match self.status { ... }`: scrutinee is plain `Status`. No reference to peel → no ergonomics → plain by-value match. Binding a non-`Copy` field (`assigned_to: String`) tries to **move** it out of data you only borrow → **E0507: cannot move out of `self.status` which is behind a shared reference**.
- `match &self.status { ... }`: you manually create a genuine `&Status`. *Now* ergonomics applies → `assigned_to` binds as `&String` (no move, just a read through the borrow). Compiles.
- `&String → &str` happens for free at the `return`/tail-expression coercion site.
- Rule of thumb: **`&` before a scrutinee matters exactly when the expression's own type isn't already a reference.**

### 3. What match ergonomics actually is (RFC 2005, 2018 edition+)
- Lets you write patterns shaped like the *owned* value even when matching a reference; compiler inserts the deref + binding mode for you.
- **Mechanism**: a `default binding mode` (`Move` / `Ref` / `RefMut`) walks the pattern in lockstep with the scrutinee's type.
  - Start at `Move`.
  - If pattern shape (no leading `&`) doesn't match scrutinee shape (a `&T`/`&mut T`), peel one reference layer off the type, flip mode to `Ref`/`RefMut`.
  - Every bare-identifier binding under that point uses the **current** mode — this is the *only* rule; it's purely structural/type-driven, never based on how the binding is later used.
  - Once in `Ref` mode, peeling further `&` layers doesn't escalate (no `ref ref`) — stays `Ref`. (This is why case 1 above collapses to "no difference.")
- An explicit `&pattern` (e.g. `Some(&n)`) opts back **out** of ergonomics at that spot: matches the reference structurally and resets to plain matching underneath — legal only if what's under it is `Copy` (else E0507 again).
- Old pre-2018 equivalent, spelled out by hand:
  ```rust
  match *opt {
      Some(ref s) => ...,   // s: &String
      None => ...,
  }
  ```
  is what `match opt { Some(s) => ... }` desugars to today.

### One-line mental model
The algorithm only ever asks, node by node: *"does my pattern's shape match my type's shape?"* — the sole corrective move it's allowed is peeling a `&`/`&mut` off the type and setting a flag ("everything below here is borrowed") that plain identifiers then obey.

---

Good question — the key insight is that this is **not** usage-driven inference (the compiler isn't looking ahead at what you do with `s` in the arm body and deciding "oh, you only read it, so I'll give you a reference"). It's a purely structural, type-directed algorithm that runs *before* the arm bodies are even checked. Let me trace it mechanically.

## The state the algorithm carries

Two pieces of state walk down the pattern and the scrutinee's type in lockstep:

- a **type cursor** — "what type am I currently looking at in the scrutinee"
- a **binding mode** — one of `Move`, `Ref`, or `RefMut` — "how should a bare identifier here be bound"

It starts at `Move` (ordinary, own-the-value matching) and only changes when it hits a reference it has to peel through.

## Trace it on your example

```rust
let opt: &Option<String> = &Some("hi".into());
match opt {
    Some(s) => { /* ??? */ }
    None => {}
}
```

| step | pattern node | type cursor | mode | action |
|---|---|---|---|---|
| 0 | `Some(s)` | `&Option<String>` | `Move` | pattern is a plain constructor (no leading `&`), but type cursor **is** a reference → **mismatch in reference-ness** |
| 1 | *(same node, retry)* | peel one `&`: cursor → `Option<String>` | flip to `Ref` | now shapes agree: pattern is a constructor, type is the enum |
| 2 | descend into `Some`'s field, pattern `s` | cursor → `String` (the field's type) | `Ref` (inherited) | pattern is a bare identifier binding with no `&`/`ref` of its own |
| 3 | bind `s` | — | `Ref` | **apply current mode**: bind by reference → `s : &String` |

That's it — there's no other input to the decision. Step 0/1 is the entire trick: *whenever the pattern shape doesn't match the type shape specifically because the type has an extra layer of `&` that the pattern doesn't, the compiler dereferences the type and remembers that it did so.* Step 3 is just "look up the current flag."

## Why it *has* to be `&String`, not a choice

This isn't the compiler being generous or optimizing — it's forced by soundness. `opt` is `&Option<String>`. You don't own an `Option<String>`; you own a borrow of one. There is no `String` sitting there for you to take — only a `String` sitting *behind someone else's reference*. So the only value that can possibly exist to bind to `s` is `&String`. If the algorithm tried to bind `s: String` instead, it would have to move the string out from behind `opt`, which — per everything from your earlier questions — is illegal unless the type is `Copy`. Match ergonomics is really just "make the pattern-matching machinery automatically do the thing that was always the *only* legal option, instead of making you write `ref` by hand to ask for it."

## Confirming it's shape-driven, not content-driven

Change nothing about how `s` is used, just change the field type to something `Copy`:

```rust
let opt: &Option<u32> = &Some(5);
match opt {
    Some(n) => { /* n: u32, not &u32! */ }
    None => {}
}
```

Wait — this one actually still gives `n: &u32`, because the *mode* (`Ref`) is set purely by the reference layer in the scrutinee's type, before the compiler even looks at whether the field is `Copy`. `Copy` only matters for the *other* direction — whether `match self.status` (a non-reference scrutinee) is allowed to bind by value. It plays no role in setting the mode when ergonomics has already switched you into `Ref`.

If you want to force an owned copy out of a `Ref`-mode match, you have to explicitly opt out at that binding:

```rust
match opt {
    Some(&n) => { /* n: u32 — explicit & pattern overrides the mode, dereferences the &u32, copies it out */ }
    None => {}
}
```

Here `&n` is a **reference pattern**: it says "I expect to see a reference here; match through it and reset to plain matching underneath." That's legal only because `u32: Copy` — try the same `Some(&n)` where the field is `String` and you're back to E0507, because now you're explicitly demanding a move out of borrowed data.

## The one-sentence mental model

The algorithm never asks "what does the programmer want to do with this binding" — it asks, at every node, "does my pattern's shape match my type's shape right now?" and the *only* corrective action it's allowed to take is peeling a `&`/`&mut` off the type and raising a flag that says "everything under here is borrowed, not owned" — a flag that plain identifier bindings simply obey.

---

**Match ergonomics** (RFC 2005, stable since the 2018 edition) is the feature that lets you write a pattern *as if* you were matching on an owned value, even when the scrutinee is actually a reference — the compiler inserts the dereferences and adjusts binding modes for you.

## The problem it solved

Before RFC 2005 (2015-edition Rust), if you matched on a reference, every level of nesting needed an explicit `&` in the pattern, and every binding needed an explicit `ref`/`ref mut` to avoid trying to move out of borrowed data:

```rust
// Old style — you had to write this by hand
match self.status {
    // wouldn't even compile without &, since self.status here is *self... 
}

fn old_style(opt: &Option<String>) {
    match opt {
        &Some(ref s) => println!("{}", s),   // explicit & to match the ref, explicit ref to bind by ref
        &None => println!("nothing"),
    }
}
```

This got unbearable fast with nested enums/structs — every layer needed its own `&`, and forgetting one meant a move error.

## What ergonomics does

Now you write the pattern shaped like the *value*, not the *reference*, and the compiler figures out the rest:

```rust
fn new_style(opt: &Option<String>) {
    match opt {
        Some(s) => println!("{}", s),   // s: &String, no & or ref anywhere
        None => println!("nothing"),
    }
}
```

## The mechanism: default binding mode

The compiler tracks a **default binding mode** as it walks the pattern alongside the scrutinee's type, starting at `move`:

- If the scrutinee is a reference (`&T` or `&mut T`) but the pattern at that position is *not* itself a reference pattern (no leading `&`), the compiler:
  1. Peels one layer of reference off the scrutinee type.
  2. Switches the default binding mode to `ref` (for `&T`) or `ref mut` (for `&mut T`).
- That mode then applies to every subsequent binding in the pattern that doesn't override it with its own explicit `&`/`ref`/`ref mut`/`&mut`.
- Once you're in `ref` mode, further reference layers don't escalate it to `ref ref` — it stays `ref`. (This is why `match &self` and `match self` behaved identically last time — peeling the second `&` didn't change anything.)
- If the pattern *does* have an explicit `&` (a "reference pattern"), that's you opting out of ergonomics for that spot and manually matching the reference structurally — which is what forces the old-style `&Some(ref s)` form to still work if you ever want it.

## Desugaring example

```rust
let opt: &Option<String> = &Some("hi".into());

match opt {
    Some(s) => { /* s: &String */ }
    None => {}
}

// is exactly equivalent to the pre-ergonomics form:
match *opt {
    Some(ref s) => { /* s: &String */ }
    None => {}
}
```

## Where it stops helping

Ergonomics only fires when the *scrutinee's actual type* is a reference. It does **not** make a plain place (like `self.status`, a field reached through `&self` but typed as `Status` itself) behave as if it were a reference — which is exactly the gap from your last question. You have to put the `&` there yourself (`&self.status`) to give the algorithm a reference to peel in the first place.

It also composes with mixed patterns — you can locally override the ambient mode:

```rust
match &(String::from("a"), String::from("b")) {
    (s1, s2) => { /* both &String, inherited ref mode */ }
}

match &(String::from("a"), 5) {
    (s, &n) => { /* s: &String (inherited); n: i32 — explicit & overrides mode, moves/copies the i32 out */ }
}
```

Here `&n` explicitly dereferences the `i32` field and copies it out (fine, `i32: Copy`); if it were a `String` you'd get the familiar E0507.

**Next natural step:** look at `ref`/`ref mut` explicitly in `let` bindings (not just `match`) — same default-binding-mode machinery applies there, and it's the same mechanism behind why `for x in &vec` gives you `x: &T` in the loop body without you writing anything special.