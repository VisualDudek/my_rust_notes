# The `Rc` Type Explained for a 5-Year-Old

Imagine you and two friends are reading the **exact same comic book** at the same time:

In Rust’s default world, a toy or a book can only have **one single owner** at a time:

* If you own the comic book, your friends can only borrow it if you are right there watching them.
* If you leave the room, the comic book goes with you.
* If you throw the book away, it's gone for everyone.

Now imagine a game where **nobody knows who will finish playing first**.

If *Alice*, *Bob*, and *Charlie* all need to look at that exact same page, but Alice might leave at 3 PM, Bob at 4 PM, and Charlie at 5 PM:

* Who should own the book?
* If Alice owns it and leaves at 3 PM, the book vanishes—leaving Bob and Charlie with empty hands.
* If Bob owns it, what happens if he leaves early?

### Enter `Rc` (Reference Counter)

`Rc` acts like a **sticky-note on the cover of the comic book that counts readers**:

1. Alice picks up the comic wrapped in an `Rc`. The sticky-note says: **1**.
2. Bob wants to share it. He doesn't make a whole new photocopy of the book; he just adds his name. The counter becomes **2**.
3. Charlie joins too. The counter becomes **3**.

Now, nobody is the "sole boss" of the book. They all share ownership.

* Alice finishes and walks away: the counter drops to **2**. The book stays on the table.
* Charlie finishes and leaves: the counter drops to **1**. Bob can still read it happily.
* Bob finally finishes and leaves: the counter drops to **0**.

Because the counter hit zero, Rust knows *nobody needs it anymore* and cleans up the comic book safely from memory.

### When do you actually need this in real code?

* **Graphs or Trees:** Think of a family tree or a network map where multiple cities point to the same hub city. Two different roads need to "own" a path to that central hub.
* **Shared read-only configuration:** Multiple parts of your app need access to a chunk of data, and any part could shut down at any time.

> **One catch:** By default, `Rc` only lets everyone **read** the comic, not scribble in it. If they also want to take turns drawing in it, you pair it with a tool like `RefCell`. Also, `Rc` is only for a single room (single-threaded)—if people are in different rooms (multiple threads), you use its big brother, `Arc`.