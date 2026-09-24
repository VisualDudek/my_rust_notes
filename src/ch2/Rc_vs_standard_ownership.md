# `Rc` vs Standard Ownership in Rust

### 1. Standard Ownership (Fails to Share)

Under default Rust ownership rules, assigning or passing a heap-allocated value moves ownership. Once moved, the original variable is invalid:

```rust
struct ComicBook {
    title: String,
}

fn main() {
    let comic = ComicBook {
        title: String::from("Spider-Man #1"),
    };

    let alice = comic; // Ownership MOVES to alice.
    // let bob = comic; // ❌ COMPILE ERROR: use of moved value: `comic`
}

```

To make this work without `Rc`, you would have to call `.clone()` on the struct itself, creating two completely separate copies in memory.

---

### 2. Shared Ownership with `Rc` (Works)

With `Rc<T>`, calling `Rc::clone(&comic)` does **not** duplicate the underlying data. It only increments an internal reference counter and gives `bob` a new pointer to the exact same heap memory.

```rust
use std::rc::Rc;

struct ComicBook {
    title: String,
}

fn main() {
    // 1. Create the comic inside an Rc. Reference count = 1.
    let comic = Rc::new(ComicBook {
        title: String::from("Spider-Man #1"),
    });
    println!("Count at start: {}", Rc::strong_count(&comic)); // 1

    // 2. Alice gets a shared handle. Reference count = 2.
    let alice = Rc::clone(&comic);
    println!("Count after Alice joins: {}", Rc::strong_count(&comic)); // 2

    // 3. Bob gets a shared handle inside a temporary inner block.
    {
        let bob = Rc::clone(&comic);
        println!("Count with Bob: {}", Rc::strong_count(&comic)); // 3
        println!("Bob is reading: {}", bob.title);
        // Bob leaves scope here. Count automatically drops back to 2.
    }

    println!("Count after Bob leaves: {}", Rc::strong_count(&comic)); // 2

    // Alice can still safely access the data.
    println!("Alice is still reading: {}", alice.title);
}

```

### Key Takeaway

| Approach | What is cloned? | Memory footprint |
| --- | --- | --- |
| `comic.clone()` | The entire inner data structure | Doubles heap memory |
| `Rc::clone(&comic)` | Just the pointer and counter | Negligible (1 pointer + 1 integer increment) |

---

> But I can always do `let bob = &comic` to get a reference without affecting ownership or reference counts? This works fine for temporary borrowing, but it doesn't give Bob independent ownership like `Rc` does.

Yes, you can do `let bob = &comic;`! In simple local code, **plain references (`&T`) are always preferred**.

However, `&T` has a strict rule enforced at compile-time: **the borrower cannot outlive the owner**.

Here is why `&T` breaks down where `Rc<T>` succeeds:

---

### Scenario 1: Returning data from a function (The Dangling Reference)

If Bob wants to keep the comic, but the function where the comic was born finishes, `&T` fails:

```rust
struct ComicBook {
    title: String,
}

// ❌ FAILS TO COMPILE
fn get_bobs_comic<'a>() -> &'a ComicBook {
    let comic = ComicBook {
        title: String::from("Spider-Man #1"),
    };
    &comic // Error: `comic` is dropped at the end of the function!
}

```

With `Rc`, Bob can take true shared ownership out of the function:

```rust
use std::rc::Rc;

// ✅ WORKS
fn get_bobs_comic() -> Rc<ComicBook> {
    let comic = Rc::new(ComicBook {
        title: String::from("Spider-Man #1"),
    });
    Rc::clone(&comic) // Moves a valid owner out; comic stays alive on the heap!
}

```

---

### Scenario 2: Independent Lifetimes in Structs

Imagine a tree or graph where two independent nodes need to refer to the same base node:

```rust
struct Node<'a> {
    parent: Option<&'a Node<'a>>,
}

```

With `&'a Node`, you are forced to add **lifetime annotations** (`'a`). This tells the compiler: *"Whatever created `parent` must live longer than this `Node`."*

If you store nodes in a dynamic list, remove them in random order, or pass them across different parts of an app, the borrow checker will fight you because it cannot statically prove who dies first.

With `Rc`:

```rust
use std::rc::Rc;

struct Node {
    parent: Option<Rc<Node>>,
}

```

* No lifetime annotations (`'a`) needed.
* Any node can hold onto `parent`.
* When the last node referencing `parent` drops, the parent is freed automatically.

---

### Comparison

* **Use `&comic**` when ownership is simple and hierarchical (e.g., the owner clearly lives longer than the borrower, like passing a reference into a helper function).
* **Use `Rc<comic>**` when lifetimes are dynamic and unpredictable (e.g., multiple structs or functions need to hold onto the data, and nobody knows who will finish using it last).
