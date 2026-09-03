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

