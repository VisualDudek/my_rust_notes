## Intro

Good phrasing of the question — let's pin down exactly what's happening in memory, because the "pointer to a pointer" structure here has real, measurable consequences.

## The layout

```rust
// Conceptually, String is:
struct String {
    ptr: *mut u8,  // pointer to heap-allocated UTF-8 bytes
    len: usize,
    cap: usize,
}
```

That's a 24-byte value (on 64-bit) that lives wherever you put it — a stack frame, a struct field, an element inside a `Vec<String>`, or on the heap if it's boxed.

`&String` is a reference *to that 24-byte struct*. Since `String` is `Sized`, `&String` is a **thin pointer** — just 8 bytes, the address of the struct.

```rust
assert_eq!(std::mem::size_of::<String>(), 24);
assert_eq!(std::mem::size_of::<&String>(), 8);
assert_eq!(std::mem::size_of::<&str>(), 16); // fat pointer: (ptr, len)
```

So `&String` does **not** point at the heap bytes. It points at the *stack slot (or wherever) holding the struct*, and that struct in turn holds the pointer to the heap. You already know `str` is a DST and `&str` is a fat pointer directly carrying `(ptr, len)` to the character data — that's the key contrast.

## Consequence 1: double indirection

Getting from a `&String` to the actual bytes is two hops:

```rust
let s = String::from("hello");
let r: &String = &s;

// hop 1: dereference &String -> String (the struct, wherever it lives)
// hop 2: String's Deref<Target = str> reads its `ptr` field -> heap bytes
let bytes: &[u8] = r.as_bytes();
```

`&str` skips hop 1 entirely — it already *is* `(ptr, len)` aimed straight at the character data. This is why `&str` is preferred as a function parameter: not just "more general" via deref coercion, but literally one less pointer chase to reach the data, and no dependency on wherever the `String` struct happens to be sitting.

```rust
fn print_it(s: &str) { println!("{s}"); }

let owned = String::from("hi");
print_it(&owned); // deref coercion: &String -> &str, done once at the call site
print_it("literal"); // &str direct, no String involved at all
```

## Consequence 2: the address of the *struct* can move independently of the heap bytes

This is the sharpest, most concrete consequence. Because `&String` points at the struct's location, not the character data, relocating the struct (e.g. a `Vec<String>` reallocating) changes what `&String` points at — while the heap-allocated bytes never move.

```rust
fn main() {
    let mut v: Vec<String> = Vec::with_capacity(1);
    v.push(String::from("hello"));

    let struct_addr_before = &v[0] as *const String as usize;
    let heap_addr_before = v[0].as_ptr() as usize;

    // Force a reallocation of the Vec's buffer
    for i in 0..10 {
        v.push(format!("filler{i}"));
    }

    let struct_addr_after = &v[0] as *const String as usize;
    let heap_addr_after = v[0].as_ptr() as usize;

    println!("struct moved: {}", struct_addr_before != struct_addr_after);
    println!("heap bytes moved: {}", heap_addr_before != heap_addr_after);
}
```

Typical output:
```
struct moved: true
heap bytes moved: false
```

The `String` *struct* got copied to a new backing buffer when the `Vec` grew — `struct_addr` changes. But the `"hello"` bytes on the heap were never touched — `heap_addr` stays put, because moving a `String` value only moves the 24-byte `(ptr, len, cap)` triple, not the buffer it points to.

This is exactly why the borrow checker refuses to let you hold a `&String` into a `Vec<String>` across a `push`: your reference targets the struct's stack/heap slot, and that slot can be invalidated by reallocation even though "the string itself" (semantically) is unaffected. It's not being overly cautious — a `&String` really would dangle if it pointed at the old struct location.

## Consequence 3: performance in hot paths

Iterating `&Vec<String>` and touching each element's bytes costs an extra cache-line fetch per element versus iterating something like `&[Box<str>]` or `Vec<&str>`, because you first load the `String` struct, *then* follow its `ptr` field. For large collections in tight loops this indirection is measurable — one more reason `Box<str>` (fat-pointer-free, no `cap` field, no growth capability) is often preferred for long-lived immutable string storage.

## The idiom this all justifies

> Take `&str` in function signatures, not `&String`.

Not just style — it's a direct consequence of `&String` being "a pointer to a place holding a pointer" rather than "a pointer straight at the data."

Since `Cow<'a, str>` and `Box<str>` are already on your roadmap, this is a natural segue: `Cow<str>` lets you defer the choice between borrowing `&str` and owning `String` until you actually need to mutate/allocate, and `Box<str>` gives you the fat-pointer directness of `&str` semantics for owned data without `String`'s extra `cap` field and growth machinery. Want to go there next, or dig into how `Deref` coercion sites decide when hop 1 gets inserted automatically?

---
## FOLLOW-UP

Good pushback — my comment was hand-wavy. Let me be precise, and also correct something: `String::as_bytes()` is actually an *inherent* method (it just returns `&self.vec[..]`), so that particular call doesn't even go through the `Deref<Target=str>` trait. The two hops are still real, but let's separate the two claims cleanly: "two memory reads at two different addresses" vs "goes through the `Deref` trait."

## Hop 1 vs Hop 2 as literal memory reads (no trait needed to see this)

```rust
fn main() {
    let s = String::from("hello");
    let r: &String = &s;

    // r is a thin pointer — just this number:
    let r_addr = r as *const String as usize;

    // ---------- HOP 1 ----------
    // Any call taking `&self` on String — even an inherent one like `.len()` —
    // has to read the 24-byte struct that lives AT r_addr. That memory read
    // is hop 1. It's not optional or sugar; it's the actual CPU load.
    let len = r.len();
    println!("hop 1: read struct at {r_addr:#x}, len field = {len}");

    // The struct's internal pointer field, exposed via as_ptr():
    let heap_addr = r.as_ptr() as usize;
    println!("that struct's ptr field holds address {heap_addr:#x}");

    // ---------- HOP 2 ----------
    // Using that field's VALUE to actually touch a byte is a second,
    // separate memory read, at a genuinely different address:
    let first_byte = unsafe { *r.as_ptr() };
    println!("hop 2: read heap at {heap_addr:#x}, byte = {first_byte} ('{}')", first_byte as char);

    assert_ne!(r_addr, heap_addr); // two distinct addresses, two distinct loads
}
```

Run this and you'll get two genuinely different addresses printed (one in the stack range, one in the heap range) — that's hop 1's target and hop 2's target, made concrete instead of asserted.

## Now the case that actually goes through `Deref`

`as_bytes`/`len`/`as_ptr` are inherent — String redefines them itself. Something like `.chars()` is **not** redefined on `String`, only on `str`, so reaching it truly requires the `Deref<Target = str>` trait. You can bypass the autoderef sugar and call it explicitly:

```rust
let s = String::from("hi");
let r: &String = &s;

// No sugar — this IS hop 1, spelled out:
// deref() reads the String struct at r's address and repackages its
// (ptr, len) fields into a fat pointer &str. It does NOT touch heap yet.
let as_str: &str = std::ops::Deref::deref(r);

// hop 2 only happens once you actually consume the bytes:
for c in as_str.chars() {   // <-- heap reads happen here, iterating
    print!("{c}-");
}
```

Worth being exact about this: `Deref::deref` itself is just "read the struct's fields, build a fat pointer" — that's hop 1's data being used to *construct* the address for hop 2. The heap isn't actually touched until something indexes or iterates the resulting `&str`. So more precisely:

- **hop 1** = reading the `String` struct's own memory (wherever `r` points) — happens on *any* `&self` call, trait or inherent.
- **hop 2** = reading the heap bytes at the address that hop 1 revealed — happens whenever the data is actually consumed (indexing, iterating, printing).

For `&str`, there's no hop 1 at all — the fat pointer `(ptr, len)` aimed at the heap already exists in the reference itself; only hop 2 (reading the bytes) ever happens.