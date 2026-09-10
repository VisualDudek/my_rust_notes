## Intro

Follow up Autoderef/Autoref in Method Resolution, how Rust/Compiler know it needs to Deref form String to &str?

Great question — the honest answer is: **the compiler isn't "guessing" to try `String → str`.** It runs one fixed, mechanical algorithm for *every* method call, on *every* type, and that algorithm happens to include "does this type implement `Deref`? If so, deref it and check again." It doesn't know anything special about `String`; it would do the exact same thing for a type you write tomorrow.

## interlude - Method Call Anatomy

What is `receiver.method(args)`?

That's just notation I used to describe the general *shape* of a method call — not special Rust syntax, just naming the parts so I can talk about them.

```rust
self.title.trim()
//   ^^^^^^ ^^^^ ^^
//   |      |    └─ args: the parenthesized argument list (empty here)
//   |      └────── method: the name after the dot
//   └───────────── receiver: the expression before the dot
```

So "`receiver.method(args)`" is just a template/placeholder for **any** method call written in that dot-call form. When I said "when the compiler sees `receiver.method(args)`, it does this...", I meant: whatever your actual receiver expression is (`self.title`, `w`, `n.0`, `some_vec`, `x.foo().bar()`'s intermediate steps, etc.), plug it into that slot and the same resolution algorithm runs.

A few concrete instantiations of the template:

| Actual code | receiver | method | args |
|---|---|---|---|
| `self.title.trim()` | `self.title` | `trim` | (none) |
| `vec.push(5)` | `vec` | `push` | `5` |
| `s.replace("a", "b")` | `s` | `replace` | `"a", "b"` |
| `w.trim()` | `w` | `trim` | (none) |

The **receiver's type** (`type_of(receiver)`) is the `T` that kicks off the deref-chain walk from my last answer. It doesn't matter how complex the receiver expression is — the compiler evaluates its type first, *then* runs method lookup on that type, completely separately from evaluating the arguments' types (which just need to match whatever parameter list the eventually-resolved method has).

So no new concept here — just vocabulary so "the receiver's type" and "the method name" have unambiguous names in an explanation.

## The algorithm, precisely

When the compiler sees `receiver.method(args)`, it does this:

**Step 1 — Build the deref chain.**
Start with `T = type_of(receiver)`. Repeatedly ask: "does `T` implement `Deref`?" If yes, push `T::Target` onto the chain and repeat with the new `T`. Stop when there's no more `Deref` impl (or you hit a recursion limit).

```
String
  → (String: Deref<Target = str> exists) → str
  → (str: Deref? no impl) → chain ends
```

This produces the base chain: `[String, str]`.

**Step 2 — Expand each entry with reference forms.**
For every type `U` in that chain, generate three candidate receiver types: `U`, `&U`, `&mut U`.

```
String   -> String, &String, &mut String
str      -> str, &str, &mut str
```

Full candidate list, in order:

```
String, &String, &mut String, str, &str, &mut str
```

**Step 3 — Walk the candidate list in order, do method lookup at each.**
For each candidate type, the compiler asks: "is there an inherent method or a visible trait method named `trim` callable on this exact type?" It checks inherent impls first, then trait impls (for types where a trait is in scope).

```
String      -> no `trim`
&String     -> no `trim`
&mut String -> no `trim`
str         -> YES: impl str { pub fn trim(&self) -> &str }
```

**It stops at the first match.** `str` has `trim`, defined as taking `&self`. Since the method needs `&self`, the compiler auto-inserts the `&` — that's the "autoref" part — giving you `&str`, which is what `trim` expects. Call resolved.

## Why this isn't special-cased for `String`

This is the crucial part: `String: Deref<Target = str>` is a completely ordinary trait impl in the standard library, no different in kind from an impl you'd write yourself:

```rust
use std::ops::Deref;

struct Wrapper(String);

impl Deref for Wrapper {
    type Target = String;
    fn deref(&self) -> &String {
        &self.0
    }
}

fn main() {
    let w = Wrapper(String::from("  hi  "));
    // w.trim() works! Because:
    // Wrapper -> (Deref) -> String -> (Deref) -> str
    // and `trim` is found on `str`.
    println!("[{}]", w.trim());
}
```

Nobody taught the compiler "if you see `Wrapper`, check `str`." It just follows `Deref` impls transitively, however many hops that takes, until it finds a type with the method — or runs out of `Deref` impls and gives up with a "method not found" error.

## Where the "knowledge" actually lives

So the answer to "how does it know" is: **it doesn't know anything about specific types — the knowledge lives entirely in the `Deref` trait impls that exist in scope**, and the algorithm is a blind, generic graph walk over whatever those impls happen to connect. `String`'s impl is what supplies the one link (`String → str`) that makes `.trim()` resolve. Delete that impl (hypothetically) and `s.trim()` would fail to compile with "no method named `trim` found for struct `String`," even though `str::trim` still exists — because there'd be no path from `String` to `str` for the compiler to walk.

## A failure case, to make the boundary concrete

```rust
struct NoDeref(String);
// no impl Deref for NoDeref

fn main() {
    let n = NoDeref(String::from("  hi  "));
    // n.trim(); // ERROR: no method named `trim` found for struct `NoDeref`
    //           // the compiler has no `Deref` edge to walk from NoDeref anywhere.
    n.0.trim(); // fine — this manually reaches into the String field first
}
```

This is also exactly why `Deref`/`DerefMut` is on your list next: implementing it isn't just "add a convenience method," it's **wiring a new edge into this method-resolution graph** for every consumer of your type, which is why the Rust book (and Clippy) are cautious about implementing `Deref` for anything that isn't genuinely a smart-pointer-like wrapper — it changes what `.method()` calls silently succeed on your type.