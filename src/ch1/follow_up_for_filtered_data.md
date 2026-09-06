## Intro

Follow-up - `Vec<&T>` for Filtered Data

Yes — exactly, and this is one of the most common real-world patterns in Rust. When `T` is heavy (a struct with `String`, `Vec`, or other owned data), you almost never want `Vec<T>` from a filter operation, because that clones every matching struct. Instead, `Vec<&T>` gives you a collection of *pointers* into the original data — no struct is copied, only the (small, fixed-size) references are stored.

## The core pattern

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

## Why this compiles without explicit lifetime annotations

You might expect to need to write out lifetimes here, but elision handles it:

```rust
fn high_earners<'a>(employees: &'a [Employee]) -> Vec<&'a Employee> {
    employees.iter().filter(|e| e.salary > 100_000.0).collect()
}
```

These two signatures are identical after elision — the compiler applies the rule "one input lifetime → assign it to all elided output lifetimes." The returned references borrow from `employees`, so the borrow checker ties the `Vec<&Employee>`'s validity to the lifetime of the slice you passed in. This is the same mechanism that makes `fn first(s: &[i32]) -> &i32` work without explicit annotation.

## The caveat: you now have a borrow, not an owned value

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

## Comparison table

| Return type | Heap cost | Lifetime tied to input? | Use when |
|---|---|---|---|
| `Vec<T>` | Clones every matched `T` | No | Need fully independent, owned results |
| `Vec<&T>` | Just pointers (Vec's own buffer) | Yes | Read-only access, input outlives usage |
| `Vec<Rc<T>>` / `Vec<Arc<T>>` | Shared ownership, refcount bump | No | Need independence but sharing is fine, no mutation |
| `impl Iterator<Item = &T>` | Zero — nothing materialized | Yes | Single consume, no need to store results |

## Natural next step

This pattern — filtering into references instead of clones — is exactly the motivation behind `Cow<'a, T>`, which is next on your list: `Cow` lets a function return "borrowed if possible, owned if a mutation is actually needed," so you get the zero-cost path in the common case and only pay for a clone when unavoidable. Want to see how `Cow` would apply if, say, some of your `high_earners` needed a computed/normalized field instead of a raw reference?
