# Pattern: `Rc` + `RefCell` = Shared Mutable State `Rc<RefCell<T>>`

A common pattern in Rust is `Rc<RefCell<T>>`.

* **`Rc<T>`** (Reference Counted) gives you **multiple owners** for the same data, but it only hands out read-only references (`&T`).
* **`RefCell<T>`** gives you **interior mutability**, letting you mutate the inner value through a read-only reference.

Together, they allow multiple owners to hold onto the exact same object and modify it independently.

---

### Example: Shared Bank Account

In this scenario, two people (Alice and Bob) share the exact same joint bank account. Both can deposit or withdraw money, and changes made by one are instantly visible to the other.

```rust
use std::cell::RefCell;
use std::rc::Rc;

#[derive(Debug)]
struct BankAccount {
    owner_names: Vec<String>,
    balance: f64,
}

impl BankAccount {
    fn new(owners: Vec<String>, balance: f64) -> Self {
        Self {
            owner_names: owners,
            balance,
        }
    }

    fn deposit(&mut self, amount: f64) {
        self.balance += amount;
    }
}

fn main() {
    // 1. Create the account wrapped in both RefCell and Rc
    let shared_account = Rc::new(RefCell::new(BankAccount::new(
        vec!["Alice".into(), "Bob".into()],
        100.0,
    )));

    // 2. Clone the Rc pointer for Alice and Bob (both point to the same allocation)
    let alice_card = Rc::clone(&shared_account);
    let bob_card = Rc::clone(&shared_account);

    // 3. Alice deposits $50
    {
        // .borrow_mut() checks out write access through the RefCell guard
        let mut account = alice_card.borrow_mut();
        account.deposit(50.0);
    } // The write lock (`account`) drops here, freeing it for others

    // 4. Bob deposits $25
    {
        let mut account = bob_card.borrow_mut();
        account.deposit(25.0);
    } // The write lock drops here

    // 5. Check the final balance using a read-only borrow
    println!(
        "Final balance: ${:.2}",
        shared_account.borrow().balance
    );

    // Both cards point to the identical data
    println!("Alice sees: ${:.2}", alice_card.borrow().balance);
    println!("Bob sees:   ${:.2}", bob_card.borrow().balance);
}

```

---

### Why the Scopes (`{ ... }`) Matter

Notice the explicit `{ ... }` blocks around `alice_card.borrow_mut()` and `bob_card.borrow_mut()`.

Calling `.borrow_mut()` returns a `RefMut<T>` smart pointer that acts as an active lock. If Alice tries to borrow the account mutably while Bob is still holding a borrow, Rust will panic at runtime:

```rust
let mut alice_ref = alice_card.borrow_mut();
let mut bob_ref = bob_card.borrow_mut(); // PANIC: AlreadyBorrowed!

```

Putting each borrow in its own scope ensures the lock drops immediately after the operation finishes. Alternatively, you can use `.try_borrow_mut()` to return a `Result` instead of crashing if the data might already be in use.