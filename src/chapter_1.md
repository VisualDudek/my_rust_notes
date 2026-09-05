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

