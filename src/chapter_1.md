# Chapter 1

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

