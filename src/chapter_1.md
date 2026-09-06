# Chapter 1

## `fold()`

Przepisz na iterator chain
```rust
pub fn ex9_word_frequency(text: &str) -> HashMap<String, u32> {
    let mut counts = HashMap::new();
    
    for word in text.split_whitespace() {
        *counts.entry(word.to_string()).or_insert(0) += 1;
    }
    counts
}
```
<details>
<summary>Show solution</summary>

- `fold()`

```rust
pub fn ex9_word_frequency(text: &str) -> HashMap<String, u32> {

    text.split_whitespace().fold(HashMap::new(), |mut counts, word| {
        *counts.entry(word.to_string()).or_default() += 1;
        counts
    })
}
```
- nie wiedziałem że moge do `acc` przypisać `HashMap::new()`
- użycie `or_default()`
- zwróć uwage na closure, zasze dostajesz do każdego kroku `|mut counts, word|`, zwróc uwage na `mut counts`

</details>

---

## lazy iterators

1. Dlaczego działa ale źle?
```rust
fn main() {
    let mut v = vec![1, 2, 3];

    v.iter_mut().map(|x| *x *= 2);

    println!("{:?}", v); // prints [1, 2, 3]
}
```

<details>
<summary>Show solution</summary>

- `map` is lazy, `|x| *x *= 2 // closure never called`

</details>

2. Dlaczego `.collect()` to głupi pomysł? ale wartościowy edukacyjnie

<details>
<summary>Show solution</summary>

```rust
fn main() {
    let mut v = vec![1, 2, 3];

    let _: Vec<()> = v.iter_mut().map(|x| *x *= 2).collect();

    println!("{:?}", v); // [2, 4, 6] — yes, this actually works
}
```

- you're forced to `collect()` into a `Vec<()>`, a vector of a "million: empty tuples, immediately thrown away.

</details>

<br>
<details>
<summary>Show final thoughts</summary>

```rust
// "I want a NEW collection, transformed"
let doubled: Vec<i32> = v.iter().map(|x| x * 2).collect();

// "I want to mutate IN PLACE, no new collection needed"
v.iter_mut().for_each(|x| *x *= 2);
```
- zwróć uwage na `iter()` vs. `iter_mut()` oraz brak konieczności dereferencji.

</details>
<br>

---

## legacy `ref`

1. What is wrong with this code?
2. Legacy and modern fix

```rust
struct Point { x: i32, y: i32 }

let optional_point: Option<Point> = Some(Point { x: 1, y: 2 });

match optional_point {
    Some(p) => println!("Coordinates are {},{}", p.x, p.y), 
    _ => panic!("No match!"),
}

println!("{:?}", optional_point.is_some());
```

<details>
<summary>Show legacy solution</summary>

```rust
struct Point { x: i32, y: i32 }

let optional_point: Option<Point> = Some(Point { x: 1, y: 2 });

match optional_point {
    Some(ref p) => println!("Coordinates are {},{}", p.x, p.y), // p: &Point
    _ => panic!("No match!"),
}

// optional_point is still valid here, because we only borrowed
println!("{:?}", optional_point.is_some());
```
- legacy: `ref` - bind this pattern variable as reference to the matched place, don't move or copy it out.

</details>

<br>

<details>
<summary>Show modern solution</summary>

```rust
struct Point { x: i32, y: i32 }

let optional_point: Option<Point> = Some(Point { x: 1, y: 2 });

match &optional_point {
    Some(p) => println!("Coordinates are {},{}", p.x, p.y), // p: &Point
    _ => panic!("No match!"),
}

// optional_point is still valid here, because we only borrowed
println!("{:?}", optional_point.is_some());
```

</details>
<br>

---

## `as_ref()` for `Option` and `Result`

`Option<T>::as_ref()` / `Result<T, E>::as_ref()` — inherent methods that convert `Option<T> -> Option<&T>` (or `Result<T,E> -> Result<&T,&E>`) without consuming the original:

```rust
let name: Option<String> = Some(String::from("Marcin"));

// Without as_ref, this would MOVE name.0 out
if let Some(n) = name.as_ref() {
    println!("{n}"); // n: &String
}

println!("{:?}", name); // still valid — we only borrowed
```

Both share a mental model: "**I own this, but I need to hand out a reference to it without giving up ownership.**" That's the whole idea — a controlled, non-consuming peek.

Use-cases:
1. inspecting without consuming, especially inside loop or before an early return
2. peeking at an `Err` before propagating 

I teraz wchodzi kluczowe pytanie: **czy `as_ref()` jest potrzebne, skoro mogę po prostu `if let Some(n) = &name`?** — ten sam rezultat:
```rust
let name: Option<String> = Some(String::from("Marcin"));

// Without as_ref, this would MOVE name.0 out
if let Some(n) = &name {
    println!("{n}"); // n: &String
}

println!("{:?}", name); // still valid — we only borrowed
```

odpowiedź to zrozumienie "match ergonomics" (a.k.a. default binding modes) — Rust automatycznie dodaje referencje w odpowiednich miejscach, aby ułatwić pracę z `&T` w `match` i `if let`. *"when the scrutinee is a reference to an enum but the pattern doesn't have '&', the compiler automatically switches to refrencing binding mode and pushes the referencing down onto the bindings inside the pattern"* so:
```rust, ignore
if let Some(n) = &name {
```
desugars conceptually to:
```rust, ignore
if let Some(ref n) = name {
```

- match ergonomics only kicks in inside **pattern matching** (`match`, `if let`, `while let`) contexts.

---

## Early return with `Result`

Chcesz wyskoczyć z funkcji na podstawie tylko jedngo "arm" w pattern mataching (albo konkretnie: propagować `Err` w `Result`)

Podejście #1 
```rust, ignore
    let qty: Result<i32, ParseIntError> = item_quantity.parse::<i32>();

    if let Err(e) = qty.as_ref() {
        return qty;
    }
    // dalej zostawia qty nie rozpakowane


    Ok(qty.unwrap() * cost_per_item + processing_fee)
    //     ^^^-- ehhh, konsekwencje tego podejścia
```

Podejście #2 — full pattern matching
```rust, ignore
    let qty: Result<i32, ParseIntError> = item_quantity.parse::<i32>();

    let qty = match qty {
        Ok(v) => v,
        Err(e) => return Err(e),
    };

    Ok(qty * cost_per_item + processing_fee)
```
- lepiej ale nie potrzebujesz używać variable shadow, możesz od razu zrobić:

```rust, ignore
    let qty = match item_quantity.parse::<i32>() {
        Ok(v) => v,
        Err(e) => return Err(e),
    };
    // at this point qty is guaranteed to be an i32, not a Result anymore

    Ok(qty * cost_per_item + processing_fee)
```

nie wkładaj logiki biznesowej do match arm — trzymaj się czystego rozpakowywania  Result<> type
```rust, ignore
    let qty: Result<i32, ParseIntError> = item_quantity.parse::<i32>();

    Ok(match qty {
        Ok(v) => v * cost_per_item + processing_fee, // <-- DO NOT DO THIS
        Err(e) => return Err(e),
    })
```

Podejście #3 — early return with `?` operator IDOMATICALLY
```rust, ignore
    let qty: i32 = item_quantity.parse::<i32>()?;
        //  ^^^-- ciekawe że infer type to nie Result<i32, ParseIntError> 
        // tylko od razu i32 dzięki `?` operatorowi

    Ok(qty * cost_per_item + processing_fee)
```

---

## Usecase for `.map_err()`

Usecase for `.map_err()`:


**Job 1: Repackage one error into another shape**

```rust
.map_err(|e| format!("...{e}"))       // ParseIntError -> String
.map_err(|e| MyError::Io(e))          // io::Error -> MyError
.map_err(MyError::Io)                 // same, tuple-struct-as-fn shorthand
```

**Job 2: Funnel *several different* error types into *one* enum**

This is where it gets useful at scale:

```rust
enum ConfigError {
    Read(std::io::Error),
    Parse(std::num::ParseIntError),
}

fn load(path: &str) -> Result<i32, ConfigError> {
    let text = std::fs::read_to_string(path)
        .map_err(ConfigError::Read)?;      // io::Error -> ConfigError

    text.trim().parse::<i32>()
        .map_err(ConfigError::Parse)?      // ParseIntError -> ConfigError
}
```

Two completely different source error types (`io::Error`, `ParseIntError`) both land in the same `ConfigError` enum, each `.map_err()` call handling the conversion right where that specific error can occur. The `?` after each line then does the early-return.

So: **`.map_err()` converts one `Result`'s error type at one call site.** "Several kinds of errors into one" is really *several `.map_err()` calls, each handling one source, all targeting the same destination enum* — not one `.map_err()` magically absorbing multiple types.

The natural next step is realizing this gets repetitive — that's exactly the itch `impl From<io::Error> for ConfigError` (or `#[from]` in `thiserror`) scratches: it lets `?` alone do what `.map_err(ConfigError::Read)?` does here, since `?` auto-converts via `From` whenever it exists.

---

## follow up: `impl From` for automatic conversion

follow up with `impl From` for automatic conversion with `?` operator.

Here's the same `ConfigError` example, but letting `?` do the conversion via `From` instead of calling `.map_err()` everywhere.

### Step 1: implement `From` for each source error

```rust
use std::fmt;

#[derive(Debug)]
enum ConfigError {
    Read(std::io::Error),
    Parse(std::num::ParseIntError),
}

impl From<std::io::Error> for ConfigError {
    fn from(e: std::io::Error) -> Self {
        ConfigError::Read(e)
    }
}

impl From<std::num::ParseIntError> for ConfigError {
    fn from(e: std::num::ParseIntError) -> Self {
        ConfigError::Parse(e)
    }
}

impl fmt::Display for ConfigError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            ConfigError::Read(e) => write!(f, "couldn't read config: {e}"),
            ConfigError::Parse(e) => write!(f, "couldn't parse config: {e}"),
        }
    }
}

impl std::error::Error for ConfigError {}
```

### Step 2: `?` alone now does the conversion

```rust
fn load(path: &str) -> Result<i32, ConfigError> {
    let text = std::fs::read_to_string(path)?;  // io::Error -> ConfigError, automatically
    let n = text.trim().parse::<i32>()?;         // ParseIntError -> ConfigError, automatically
    Ok(n)
}
```

No `.map_err()` in sight. Compare to what you had before:

```rust
// before
let text = std::fs::read_to_string(path).map_err(ConfigError::Read)?;
let n = text.trim().parse::<i32>().map_err(ConfigError::Parse)?;

// after
let text = std::fs::read_to_string(path)?;
let n = text.trim().parse::<i32>()?;
```

### What's actually happening

`?` desugars roughly to:

```rust
match std::fs::read_to_string(path) {
    Ok(v) => v,
    Err(e) => return Err(From::from(e)),
}
```

That `From::from(e)` is the whole trick — `?` looks for a `From<SourceError> for TargetError` impl and calls it automatically whenever the error type doesn't already match the function's return type. You wrote the conversion logic once, in the `impl From` block, instead of at every call site.

### Same thing, but with `thiserror`

Writing `Display`, `Error`, and `From` by hand for every variant gets repetitive fast. `thiserror` generates all of it from attributes:

```rust
// Cargo.toml: thiserror = "1"
use thiserror::Error;

#[derive(Debug, Error)]
enum ConfigError {
    #[error("couldn't read config: {0}")]
    Read(#[from] std::io::Error),

    #[error("couldn't parse config: {0}")]
    Parse(#[from] std::num::ParseIntError),
}

fn load(path: &str) -> Result<i32, ConfigError> {
    let text = std::fs::read_to_string(path)?;
    let n = text.trim().parse::<i32>()?;
    Ok(n)
}
```

`#[from]` generates exactly the `impl From<...>` blocks you wrote by hand above. `#[error("...")]` generates the `Display` impl. Function body is identical either way — this is purely about not hand-writing boilerplate.

### Mental model, updated

- `.map_err(F::from)` / `.map_err(Variant)` — explicit, per-call-site conversion
- `impl From<E> for MyError` — conversion logic defined once
- `?` — automatically invokes that `From` impl at every call site, so you never call `.map_err()` for a conversion `From` already knows how to do

`.map_err()` is still useful when the conversion *isn't* a clean `From` — e.g. you want to attach context that only exists at that call site (a filename, a line number) rather than a pure type-to-type mapping. That's the case `anyhow`'s `.context()` / `with_context()` is built for, if you want to see that next.

---

## `if` or `let if` without `else` branch -> type

Z czym tu jest problem i dlaczego?

```rust
pub fn first_word(s: &str) -> &str {
    if let Some(n) = s.find(' ') {
       &s[0..n]
    } 
    s
}
```

<br>
<details>
<summary>Show solution</summary>

An `if let` (or plain `if`) **without an `else` branch** is treated by the compiler as having an implicit `else { }`. Since that implicit else evaluates to `()`, the *then* branch must also evaluate to `()` for the two arms to unify to a single type — the same rule that governs a plain `if` without `else` used as an expression.

So `&s[0..n]` as a tail expression (no semicolon) has type `&str`, but the compiler needs `()` — mismatch, hard error.

```rust
// Solution #1
pub fn first_word(s: &str) -> &str {
    if let Some(n) = s.find(' ') {
       return &s[0..n];
    } 
    s
}
```

<br>

```rust
// Solution #2
pub fn first_word(s: &str) -> &str {
    if let Some(n) = s.find(' ') {
       &s[0..n]
    } else {
        s
    }
}
```

<br>

```rust
// Solution #3
pub fn first_word(s: &str) -> &str {
    match s.find(' ') {
        Some(n) => &s[0..n],
        None => s,
    }
}
```
<br>

```rust
// Solution #4
pub fn first_word(s: &str) -> &str {
    s.split(' ').next().unwrap_or(s)
}
```

<br>

```rust
// Solution #5
pub fn first_word(s: &str) -> &str {
    s.find(' ').map_or(s, |n| &s[0..n])
}
```
</details>
<br>

---

## Iterator adapters

Jak jest różnica:

```rust
fn ex6_double_all(numbers: &[i32]) -> Vec<i32> {
    numbers.iter().map(|x| x * 2 ).collect()
}
```
vs.
```rust
fn ex6_double_all(numbers: &[i32]) -> Vec<i32> {
    numbers.iter().map(|x| x *= 2 ).collect()
}
```

### Setup: what `x` actually is

```rust
fn ex6_double_all(numbers: &[i32]) -> Vec<i32> {
    numbers.iter().map(|x| x * 2).collect()
}
```

`numbers.iter()` yields `Item = &i32`. So in the closure, `x: &i32`.

### Version 1: `x * 2` — works

```rust
numbers.iter().map(|x| x * 2).collect()
```

`*` here is **multiplication**, not dereference. The expression is `x * 2` where `x: &i32` and `2: i32`. This compiles because std provides forwarding impls like:

```rust
impl<'a> Mul<i32> for &'a i32 { type Output = i32; ... }
```

So `&i32 * i32 -> i32` works directly — no explicit `*x` needed, the trait impl handles the reference side. The closure returns `i32`, `map` produces `impl Iterator<Item = i32>`, and `collect()` builds `Vec<i32>`. Everything lines up with the return type.

### Version 2: `x *= 2` — does **not** compile

```rust
numbers.iter().map(|x| x *= 2).collect()
```

Two separate problems here:

**1. `x` isn't a mutable binding.** Closure parameters behave like `let` bindings — to reassign or mutate through `x`, the parameter needs to be `mut x`. As written, `x` is immutable, so any assignment through it is rejected immediately: `cannot assign to x, as it is not declared as mutable`.

**2. Even with `mut x`, the semantics are wrong.** `x *= 2` (without a `*` prefix) means "reassign the binding `x`, calling `MulAssign::mul_assign` on `x` itself" — i.e. it wants `impl MulAssign<i32> for &i32`, treating the *reference* as the thing being multiplied. That impl doesn't exist in std (it wouldn't even make sense — multiplying a pointer by 2 isn't a rebinding operation Rust exposes this way). What you'd actually want is `*x *= 2`, which dereferences to the pointee place and calls `<i32 as MulAssign<i32>>::mul_assign(&mut *x, 2)` — but that additionally requires `x: &mut i32`, and `iter()` only gives you `&i32` (shared refs), so you'd need `iter_mut()` on a mutable slice for that to even type-check.

**3. Return type mismatch.** `x *= 2` is an assignment expression, which evaluates to `()`, not `i32`. So even in a hypothetical world where the trait bound existed, the closure would return `()`, `map` would yield `impl Iterator<Item = ()>`, and `collect()` couldn't produce `Vec<i32>` — a type mismatch against the function's declared return type.

### The idiomatic mental model

| Goal | Correct approach |
|---|---|
| Compute a new value from a shared reference | `x * 2` (arithmetic ops are implemented for `&T` via forwarding impls) |
| Mutate the underlying data in place | Need `&mut i32` (via `iter_mut()`), then `*x *= 2` |

If you actually wanted to double the elements *in place* rather than produce a new `Vec`, the mutating version would look like:

```rust
fn ex6_double_all_in_place(numbers: &mut [i32]) {
    numbers.iter_mut().for_each(|x| *x *= 2);
}
```

Here `x: &mut i32`, and `*x *= 2` dereferences to the `i32` place and mutates it — `for_each` is used instead of `map`/`collect` because the closure now has a side effect and returns `()`, which is exactly what `for_each` expects.

This is a nice bridge into your upcoming `iter_mut()` + `filter` topic — the double-reference gotcha (`&&T` in `filter` on `Iterator<Item = &T>`) has a mirror image here: with `iter_mut()`, your closures receive `&mut T`, and you always need the leading `*` to reach the pointee before applying a compound assignment operator.

---

## Can a Rust Slice Represent Filtered Data?

I am thinking about an exercise like this:

```rust
fn ex7_middle_slice(numbers: &[i32]) -> &[i32] {
    &numbers[1..numbers.len() - 1]
}
```

Here, returning a slice works because the result refers to a contiguous region of the original input slice.

But what if I wanted to return only the even numbers from `numbers`?

My understanding is that returning `&[i32]` would not be possible in the general case. A slice is essentially a fat pointer consisting of a pointer to the first element and a length, so it can only describe a contiguous region of memory. Even numbers in the original slice may be located at non-contiguous addresses.

For example:

```text
[1, 2, 3, 4, 5, 6]
    ^     ^     ^
```

The values `2`, `4`, and `6` do not form one contiguous region in the original slice, so they cannot be represented as a single `&[i32]`.

One alternative would be to return a filtered iterator, for example:

```rust
numbers.iter().filter(|&&x| x % 2 == 0)
```

However, an iterator is stateful and is consumed as it is iterated over, so it behaves differently from a reusable slice.

What would be the idiomatic Rust solution here?

Would you recommend:

* returning an iterator,
* allocating a new `Vec<i32>`,
* returning a `Vec<&i32>`,
* or using another approach?

Your reasoning is exactly right, and it's a great instinct to check. A slice `&[i32]` is fundamentally a `(pointer, length)` pair into a **contiguous** region of memory. If the even numbers aren't contiguous in the original buffer, there's no way to describe "just the evens" with a single pointer+length — you'd need multiple disjoint ranges, which a slice cannot express.

So `fn evens(numbers: &[i32]) -> &[i32]` is only satisfiable if you either get lucky (the evens already happen to be a contiguous run) or you physically **reorder** the underlying data so they become contiguous. That reordering insight is actually the key to one of the real solutions below.

### Option 1 — In-place partition, return a real slice (zero allocation)

If you're allowed to take `&mut [i32]` instead of `&[i32]`, you can *rearrange* the slice so all evens come first, then return a sub-slice of the front. This is the same idea behind `slice::partition_point` / quicksort's partition step, or `Vec::retain`'s swap-remove-like shuffling.

```rust
/// Reorders `numbers` so all even values come first (order not preserved),
/// then returns a slice covering just those even values.
fn partition_evens(numbers: &mut [i32]) -> &[i32] {
    let mut write = 0;
    for read in 0..numbers.len() {
        if numbers[read] % 2 == 0 {
            numbers.swap(write, read);
            write += 1;
        }
    }
    &numbers[..write]
}
```

This is genuinely idiomatic for performance-sensitive code (it's basically what `Vec::retain` and the standard library's own partitioning routines do internally) — **zero heap allocation**, single pass, real slice semantics. The trade-off: it mutates the caller's data and doesn't preserve relative order of the evens (a stable partition would need either extra memory or a slower algorithm).

If you need order preserved *and* in-place, that's a stable partition — doable but costs either O(n) extra space or a rotation-based algorithm (more advanced, not usually worth it unless order matters).

### Option 2 — Return an owned `Vec<i32>` (simplest, most common)

If contiguity isn't achievable or desirable, the standard move is to stop promising a slice and just hand back ownership of a new buffer:

```rust
fn evens(numbers: &[i32]) -> Vec<i32> {
    numbers.iter().copied().filter(|n| n % 2 == 0).collect()
}
```

This is what 90% of real-world Rust code does for "filter and give me the results" — allocation is cheap relative to the clarity you get, and `Vec<i32>` derefs to `&[i32]` anywhere a slice is expected via `Deref<Target = [i32]>`, so callers barely notice the difference.

### Option 3 — Return a lazy iterator (zero allocation, but not a slice)

If you don't need a concrete buffer at all — just something the caller can iterate — return `impl Iterator`:

```rust
fn evens(numbers: &[i32]) -> impl Iterator<Item = &i32> {
    numbers.iter().filter(|n| **n % 2 == 0)
}
```

You correctly flagged the trap here: an iterator is lazy and single-use — it doesn't "contain" values, it *produces* them once, on demand, via repeated `.next()` calls. That's not a downside so much as a different contract: this is perfect when the caller is going to consume it once anyway (e.g. `for x in evens(&data) { ... }` or `.sum()`), because you avoid ever materializing an intermediate buffer.

### Recommendation

| Goal | Choice |
|---|---|
| Learning exercise fidelity to "return a slice" | Option 1 (in-place partition) — this is the *only* way to honestly return `&[i32]` |
| Real-world "give me the evens" utility | Option 2 (`Vec<i32>`) — simplest, most idiomatic, order-preserving |
| Feeding into a `for` loop / another adapter chain, no buffer needed | Option 3 (`impl Iterator`) |

For a rustlings-style exercise, Option 1 is the most pedagogically interesting because it forces you to confront *why* slices can't do arbitrary selection — and it's a nice bridge toward `Vec::retain`'s actual implementation, and later, `slice::sort_by`/partitioning algorithms, which use the exact same swap-based technique.

Want me to write this up as a full exercise/solution pair (with `#[cfg(test)]` blocks) for your workspace — maybe including both the mutating in-place version and the `Vec`-returning version so the contrast is explicit?

---

## Follow-up - `Vec<&T>` for Filtered Data

Yes — exactly, and this is one of the most common real-world patterns in Rust. When `T` is heavy (a struct with `String`, `Vec`, or other owned data), you almost never want `Vec<T>` from a filter operation, because that clones every matching struct. Instead, `Vec<&T>` gives you a collection of *pointers* into the original data — no struct is copied, only the (small, fixed-size) references are stored.

### The core pattern

```rust
struct Employee {
    name: String,
    department: String,
    salary: f64,
    notes: String, // imagine this is a big blob of text
}

fn high_earners(employees: &[Employee]) -> Vec<&Employee> {
    employees.iter().filter(|e| e.salary > 100_000.0).collect()
}
```

Here's the important nuance about "saving heap allocation": you're not eliminating *all* allocation — the `Vec<&Employee>` itself still needs a heap buffer to hold the references. What you're eliminating is allocation *of the heavy data*. A `&Employee` is just a pointer (8 bytes on 64-bit), regardless of how large `Employee` is. So instead of copying potentially kilobytes of `String` data per match, you're copying an 8-byte pointer per match. That's the win.

### Why this compiles without explicit lifetime annotations

You might expect to need to write out lifetimes here, but elision handles it:

```rust
fn high_earners<'a>(employees: &'a [Employee]) -> Vec<&'a Employee> {
    employees.iter().filter(|e| e.salary > 100_000.0).collect()
}
```

These two signatures are identical after elision — the compiler applies the rule "one input lifetime → assign it to all elided output lifetimes." The returned references borrow from `employees`, so the borrow checker ties the `Vec<&Employee>`'s validity to the lifetime of the slice you passed in. This is the same mechanism that makes `fn first(s: &[i32]) -> &i32` work without explicit annotation.

### The caveat: you now have a borrow, not an owned value

This is the trade-off that matters most:

```rust
fn main() {
    let employees = vec![/* ... */];
    let earners = high_earners(&employees);
    
    // employees is still borrowed here — earners holds &Employee into it
    // employees.push(...) // ERROR: cannot borrow `employees` as mutable
    //                       because it's also borrowed as immutable
    
    println!("{}", earners[0].name);
} // earners drops, then employees can be freed
```

`Vec<&Employee>` can't outlive `employees`, and you can't mutate `employees` while `earners` is alive (that's the aliasing XOR mutability invariant you already know from `&T`/`&mut T`). If you need the filtered results to outlive the source, or to mutate the source afterward, you're back to needing owned data — either `Vec<Employee>` (full clones) or `Vec<Rc<Employee>>` / `Arc<Employee>` if shared ownership across scopes is the actual requirement.

### Comparison table

| Return type | Heap cost | Lifetime tied to input? | Use when |
|---|---|---|---|
| `Vec<T>` | Clones every matched `T` | No | Need fully independent, owned results |
| `Vec<&T>` | Just pointers (Vec's own buffer) | Yes | Read-only access, input outlives usage |
| `Vec<Rc<T>>` / `Vec<Arc<T>>` | Shared ownership, refcount bump | No | Need independence but sharing is fine, no mutation |
| `impl Iterator<Item = &T>` | Zero — nothing materialized | Yes | Single consume, no need to store results |

### Natural next step

This pattern — filtering into references instead of clones — is exactly the motivation behind `Cow<'a, T>`, which is next on your list: `Cow` lets a function return "borrowed if possible, owned if a mutation is actually needed," so you get the zero-cost path in the common case and only pay for a clone when unavoidable. Want to see how `Cow` would apply if, say, some of your `high_earners` needed a computed/normalized field instead of a raw reference?

---

