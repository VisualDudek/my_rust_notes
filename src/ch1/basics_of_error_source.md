## Introduction

> Prompt: show me basic example of this statemant "The `source` method allows you to “walk” the full chain of errors, often used when capturing error context in logs."

Let me show you how `Error::source()` works with a practical example — this is one of those features that seems abstract until you see it solve a real problem: figuring out *why* a high-level error actually happened.

## The Mental Model

Rust's error handling encourages wrapping low-level errors in higher-level, more meaningful ones as they propagate up through your call stack. But wrapping loses information unless you keep a reference to the original error. The `std::error::Error` trait's `source()` method is the standardized way to preserve that link:

```rust
pub trait Error: Debug + Display {
    fn source(&self) -> Option<&(dyn Error + 'static)> {
        None
    }
}
```

Each error in the chain points to the error "beneath" it, like a linked list. `source()` returns `None` when you've hit the root cause.

## Basic Example: Building a Chain

```rust
use std::error::Error;
use std::fmt;

// --- Low-level error (the root cause) ---
#[derive(Debug)]
struct DatabaseError {
    detail: String,
}

impl fmt::Display for DatabaseError {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "database error: {}", self.detail)
    }
}

impl Error for DatabaseError {} // no source() override -> defaults to None

// --- Mid-level error, wraps the database error ---
#[derive(Debug)]
struct RepositoryError {
    source: DatabaseError,
}

impl fmt::Display for RepositoryError {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "failed to load user record")
    }
}

impl Error for RepositoryError {
    fn source(&self) -> Option<&(dyn Error + 'static)> {
        Some(&self.source) // <-- points down the chain
    }
}

// --- High-level error, wraps the repository error ---
#[derive(Debug)]
struct ServiceError {
    source: RepositoryError,
}

impl fmt::Display for ServiceError {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "could not process request")
    }
}

impl Error for ServiceError {
    fn source(&self) -> Option<&(dyn Error + 'static)> {
        Some(&self.source)
    }
}

fn main() {
    let db_err = DatabaseError {
        detail: "connection timed out".to_string(),
    };
    let repo_err = RepositoryError { source: db_err };
    let service_err = ServiceError { source: repo_err };

    // "Walking" the chain — this is the pattern you'll see in logging code
    let mut current: &dyn Error = &service_err;
    println!("{}", current);

    while let Some(cause) = current.source() {
        println!("  caused by: {}", cause);
        current = cause;
    }
}
```

**Output:**
```
could not process request
  caused by: failed to load user record
  caused by: database error: connection timed out
```

## Why This Matters

Without `source()`, `ServiceError`'s `Display` message alone ("could not process request") is useless for debugging — you'd have no idea the actual cause was a database timeout. By preserving the chain, logging code can walk it and print (or structure) the full causal history without every layer needing to know the details of the layer beneath it. This is exactly what libraries like `anyhow` do automatically when you call `.context(...)` — under the hood, it's building this same chain and its `Debug` impl walks `source()` to print it for you.

## A Common Idiom: A Generic "Print the Chain" Helper

Since walking the chain is such a common need, it's worth writing once and reusing:

```rust
fn log_error_chain(err: &dyn Error) {
    eprintln!("Error: {}", err);
    let mut source = err.source();
    while let Some(cause) = source {
        eprintln!("Caused by: {}", cause);
        source = cause.source();
    }
}
```

## Note on `thiserror`

If you're using `thiserror` (which you likely will for this pattern in real projects), it generates the `source()` implementation for you when you annotate a field with `#[source]` or `#[from]`:

```rust
use thiserror::Error;

#[derive(Error, Debug)]
#[error("could not process request")]
struct ServiceError {
    #[source]
    source: RepositoryError,
}
```

This is much less boilerplate than the manual `impl Error for ServiceError` above — same chain, generated for free.

**Next step to explore:** try `anyhow::Error`'s `chain()` iterator (`err.chain()`), which is a ready-made iterator over exactly this walk — useful once you're not defining your own error types and are just propagating `anyhow::Result` up through an application.