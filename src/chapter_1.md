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

---

