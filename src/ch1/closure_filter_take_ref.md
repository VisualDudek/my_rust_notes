# Closure passed to `filter` takes a reference

> do not understand why in following code inside fileter ticket is type &&Ticket, why double ref ?

```rust
#[derive(Clone)]
pub struct TicketStore {
    tickets: Vec<Ticket>,
}

#[derive(Clone, Debug, PartialEq)]
pub struct Ticket {
    pub title: TicketTitle,
    pub description: TicketDescription,
    pub status: Status,
}

impl TicketStore { ...

 pub fn to_dos(&self) -> Vec<&Ticket> {
        self.tickets.iter()
            .filter(|&ticket| ticket.status == Status::ToDo)
            // At this point, the iterator still yields &Ticket, not &&Ticket.
            // The closure parameter `|&ticket|` destructures the `&&Ticket` into `&Ticket`.
            .collect()
            // .collect::<Vec<&Ticket>>()
    }
```

Good question — this trips up almost everyone once they start chaining iterator adaptors. Let's trace the types step by step.

## Why the double reference appears

```rust
pub fn to_dos(&self) -> Vec<&Ticket> {
    self.tickets.iter()                              // Iterator<Item = &Ticket>
        .filter(|&ticket| ticket.status == Status::ToDo)
        .collect()
}
```

Assume `self.tickets: Vec<Ticket>`.

1. `.iter()` on a `Vec<Ticket>` yields `Item = &Ticket`. It doesn't hand you owned `Ticket`s — that would require moving them out of the vec, which you don't want since `self` is only borrowed (`&self`).

2. `Iterator::filter`'s closure doesn't take `Item` by value — it takes **a reference to** the item, because `filter` only needs to *inspect* the element to decide keep/discard; it doesn't need ownership. Its signature is:

```rust
fn filter<P>(self, predicate: P) -> Filter<Self, P>
where
    P: FnMut(&Self::Item) -> bool,
```

So the predicate receives `&Self::Item`. Since `Self::Item` is already `&Ticket`, the predicate parameter type is `&&Ticket` — a reference to a reference. That's your double ref, and it's completely mechanical: it falls straight out of composing "iterator over references" with "filter takes a reference to the item."

## Why `|&ticket|` works

The pattern `|&ticket|` is a **destructuring pattern**, not just a variable name — it pattern-matches on the outer `&`, peeling one layer off. So:

- Closure parameter type: `&&Ticket`
- Pattern `&ticket` destructures the outer `&`
- Binding `ticket` inside the closure body: `&Ticket`

That's why `ticket.status` works cleanly inside — you're back down to a single reference, and `.status` field access works through one level of `Deref`-like auto-referencing anyway (method/field access auto-derefs), but matching down explicitly like this is the idiomatic style for `filter`.

The equivalent without the destructuring pattern:

```rust
.filter(|ticket| ticket.status == Status::ToDo)
//       ^^^^^^ type is &&Ticket here
//       ticket.status still works! field access auto-derefs through both layers
```

This *also* compiles, because Rust's field/method access auto-dereferences as many layers as needed. So `|&ticket|` vs `|ticket|` here is purely a style choice — the `&` pattern is common because it makes the type explicit and avoids you accidentally thinking `ticket` is `&Ticket` when reading the body.

## Why `.collect()` produces `Vec<&Ticket>`, not `Vec<&&Ticket>`

`filter` doesn't change the item type — it only filters. So after `.filter(...)`, the iterator is still `Item = &Ticket` (the outer `&&Ticket` was only the *predicate's parameter type*, never the *iterator's item type*). `.collect()` then collects `&Ticket`s into `Vec<&Ticket>`, matching your return type.

## The mental model to keep

> Whenever you see `&&T`, ask: "reference to what?" Almost always it's **"a reference the iterator already yields" + "a reference the combinator takes to inspect the item without owning it."** It's not Rust being weird — it's two independent "give me a reference" decisions stacking.

You'll see the same pattern with `Iterator::find`, `Iterator::any`, `Iterator::all` — anything that only needs to *look at* an item takes `&Item`.

## Idiomatic tightening

For readability in real code, many style guides prefer avoiding the double-ref pattern-match and instead comparing through the auto-deref:

```rust
pub fn to_dos(&self) -> Vec<&Ticket> {
    self.tickets
        .iter()
        .filter(|ticket| ticket.status == Status::ToDo)
        .collect()
}
```

Both are correct and idiomatic; `|&ticket|` is slightly more explicit about "I'm working with `&Ticket` in here," `|ticket|` relies on auto-deref and is what you'll see most often in the wild (e.g. in `clippy`-clean codebases).

**Next step worth exploring:** the same double-reference confusion shows up with `Iterator::map` when you do `.iter().map(|x| ...)` versus `.into_iter()`, and it's foundational for understanding `Cow`, `Deref` coercion, and why `&Vec<T>` argument types are usually an anti-pattern (prefer `&[T]`). Want me to walk through that next?