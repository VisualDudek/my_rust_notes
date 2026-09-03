# mdBook: A Practical Getting-Started Guide

Goal: build a notes site structured like Rustlings — topics broken into short lessons, each paired with a practice exercise.

---

## 1. What mdBook is and where it sits in the ecosystem

mdBook is a Rust CLI tool that renders a directory of Markdown files into a static, searchable HTML book. It's written and maintained under the `rust-lang` GitHub org, and it's the tool that produces most of the official Rust documentation you already use: *The Rust Programming Language* book, *The Rust Reference*, *The Rustonomicon*, *The Cargo Book*, *The rustc Dev Guide*, and Rust Edition Guides are all mdBook output. That's the main reason it's the default choice for Rust-adjacent documentation projects — it's the same toolchain the language itself uses, it's a single static binary with no runtime dependency, and its output is just HTML/CSS/JS you can host anywhere (GitHub Pages, Netlify, a plain nginx box).

It is not a general-purpose static site generator (no blog/CMS features) — it's specifically a "book" renderer: linear/hierarchical chapters, a sidebar TOC, built-in search, and strong defaults for embedding code. That narrower scope is exactly what makes it a good fit for a lessons+exercises notes site instead of, say, Hugo or mdx-based tools.

### Installing it

```sh
cargo install mdbook
```

This builds from source via crates.io and installs the `mdbook` binary into `~/.cargo/bin` (make sure that's on your `PATH`, which it almost certainly already is given your Rust setup). A few notes:

- Add `--locked` if you want reproducible dependency versions: `cargo install mdbook --locked`.
- To upgrade later: `cargo install mdbook --force` (or `cargo install-update` if you use `cargo-update`).
- Check what you got: `mdbook --version`.
- **Version note:** mdBook hit a major version bump with **0.5.0** (released November 2025), after over 130 PRs since 0.4.52. It's primarily an internal API/architecture rewrite (splitting `mdbook` into `mdbook-core`, `mdbook-driver`, `mdbook-html`, `mdbook-preprocessor`, etc.) aimed at plugin authors, not at people just writing content. If you're starting fresh today, `cargo install mdbook` will just get you 0.5.x — good. The only place this bites *you* as an author: any third-party preprocessor/plugin you add later (mermaid diagrams, KaTeX math, etc.) needs a release that's compatible with the 0.5 preprocessor API. Check the plugin's changelog for "mdBook 0.5" support before installing it.

---

## 2. Initializing a project and the resulting layout

```sh
mdbook init my-rust-notes
cd my-rust-notes
```

You'll be prompted for a title (or pass `--title "My Rust Notes"` to skip the prompt) and asked whether to create a `.gitignore`. Non-interactive form for scripting:

```sh
mdbook init my-rust-notes --title "My Rust Notes" --ignore git
```

Resulting structure:

```
my-rust-notes/
├── book.toml
└── src/
    ├── SUMMARY.md
    └── chapter_1.md
```

- **`book.toml`** — project config: metadata, build settings, HTML renderer options, preprocessor/plugin config. Analogous to `Cargo.toml`.
- **`src/`** — all your Markdown content lives here. This is the thing you'd point an editor/watcher at.
- **`src/SUMMARY.md`** — the *only* file mdBook reads to figure out your book's structure (see §3). Every chapter must be linked from here or it won't be built.
- **`src/chapter_1.md`** — a placeholder first chapter.

When you build, mdBook writes rendered output to `book/` (or whatever `build.build-dir` says) at the project root, as a sibling to `src/`. That output directory is disposable/generated — worth adding to `.gitignore` if you didn't do it at init time.

**Gotcha:** don't confuse `src/` here with a Cargo `src/`. If you later want a *separate* Cargo crate holding runnable example/exercise code alongside the book (common in Rustlings-style projects, so exercises compile with `cargo test`), keep that crate in its own top-level directory (e.g. `exercises/`) outside `src/`, since mdBook will otherwise try to treat every `.rs` file under `src/` as something to walk for Markdown-embedded snippets — it won't break anything, but it's confusing layout-wise. More on the lesson+exercise pairing pattern in §7.

---

## 3. `SUMMARY.md` and chapter/exercise nesting

`SUMMARY.md` is a restricted Markdown list — mdBook parses its link structure to build both the sidebar TOC and the actual page hierarchy (URLs are derived from it). Basic form:

```markdown
# Summary

[Introduction](README.md)

- [Chapter 1](./chapter_1.md)
- [Chapter 2](./chapter_2.md)
```

- The optional `# Summary` heading and an optional prefix link (like `[Introduction]`) render outside/above the numbered list in the sidebar.
- Each `- [Title](path)` becomes a numbered chapter.
- **Nesting is just Markdown list indentation.** This is the key mechanism for your lesson+exercise layout:

```markdown
# Summary

[Introduction](README.md)

- [Ownership](./ownership/index.md)
  - [Lesson: Move Semantics](./ownership/lesson.md)
  - [Exercise: Fix the Borrow Checker](./ownership/exercise.md)
  - [Solution](./ownership/solution.md)
- [Lifetimes](./lifetimes/index.md)
  - [Lesson: Elision Rules](./lifetimes/lesson.md)
  - [Exercise: Annotate the Signatures](./lifetimes/exercise.md)
  - [Solution](./lifetimes/solution.md)
```

A natural mirrored file layout for this:

```
src/
├── SUMMARY.md
├── README.md
├── ownership/
│   ├── index.md
│   ├── lesson.md
│   ├── exercise.md
│   └── solution.md
└── lifetimes/
    ├── index.md
    ├── lesson.md
    ├── exercise.md
    └── solution.md
```

A few extra `SUMMARY.md` conventions worth knowing:

- **Draft chapters** — a list item with no link, `- [Coming Soon]()`, renders in the sidebar as unlinked/greyed-out text. Handy for stubbing out your syllabus before you've written the content.
- **Part titles** — a plain (non-list) line acts as a section separator/heading between groups of chapters:

  ```markdown
  # Summary

  [Introduction](README.md)

  # Part I: Fundamentals

  - [Ownership](./ownership/index.md)

  # Part II: Advanced Types

  - [Trait Objects](./traits/index.md)
  ```

  This is the cleanest way to group topics ("Fundamentals", "Concurrency", "Unsafe") above the per-topic lesson/exercise nesting.
- Nesting depth isn't hard-limited, but keep it to 2–3 levels — the default theme's sidebar gets visually noisy past that, and it stops matching how Rustlings itself is organized (flat-ish per-exercise).
- **Common beginner mistake:** creating a file under `src/` and forgetting to add it to `SUMMARY.md`. mdBook will *not* auto-discover it, and it also won't error — the page just silently won't appear in the book (though `mdbook build` does warn about `.md` files present in `src/` but missing from `SUMMARY.md`, so watch the terminal output).

---

## 4. Writing and previewing locally

```sh
mdbook build          # one-shot render to book/
mdbook serve           # build + serve on http://localhost:3000 + watch + live reload
mdbook serve --open    # same, and opens your browser automatically
mdbook watch            # like serve, but rebuilds on change without hosting an HTTP server
```

`mdbook serve` is what you want for the actual writing loop: it starts a local HTTP server, injects a small JS live-reload client into the pages, and rebuilds + auto-refreshes your browser tab whenever a file under `src/` (or `book.toml`) changes. Default port is 3000; override with `-p`:

```sh
mdbook serve -p 8000 --open
```

If you want the watcher to also trigger on files *outside* `src/` — e.g. a separate `exercises/` Cargo crate you're cross-referencing — add them to `book.toml`:

```toml
[build]
extra-watch-dirs = ["exercises"]
```

**Gotcha:** `mdbook serve`'s live-reload works by rewriting content on the fly; it does not write the reloaded content to `book/` on disk the same way `mdbook build` does after every keystroke (it's efficient about it), so if you're also trying to deploy straight from a stale `book/` directory mid-editing-session, run a final `mdbook build` before publishing.

---

## 5. Code blocks, syntax highlighting, and runnable/testable Rust

Fenced code blocks with a `rust` (or `rs`) language tag get Rust-aware syntax highlighting automatically — no config needed:

```rust
fn main() {
    println!("Hello, world!");
}
```

Beyond highlighting, mdBook has several Rust-specific behaviors baked in that are directly relevant to Rustlings-style content:

**a) Every `rust` code block gets a Playground "run" button by default.** mdBook sends the snippet to `play.rust-lang.org` and shows output inline in the reader's browser. If there's no `fn main()`, mdBook auto-wraps your snippet in one before sending it. This is essentially free "run this exercise in-browser" behavior with zero setup.

- Disable it per-block with `noplayground`:

  ````markdown
  ```rust,noplayground
  let x = 5; // fragment, not meant to run standalone
  ```
  ````

**b) `editable` makes the code block an editable text area** (instead of read-only-but-runnable), which is the closer match to a Rustlings "fill in the blank and run it" exercise feel:

````markdown
```rust,editable
fn main() {
    // TODO: fix this
    let x: u32 = -1;
    println!("{}", x);
}
```
````

Combine with `ignore` if you don't want this snippet compiled during `mdbook test` (see below) because it's intentionally broken:

````markdown
```rust,editable,ignore
fn broken() {
    this doesnt compile on purpose
}
```
````

**c) Hidden lines, rustdoc-style.** Prefix a line with `# ` (hash + space) to hide it from the rendered book while still including it when the code is run/tested — exactly like rustdoc doc-tests. Great for hiding boilerplate (`fn main() { ... }` wrappers, imports) around a focused exercise snippet:

````markdown
```rust
# fn main() {
let x = 5;
let y = 6;
println!("{}", x + y);
# }
```
````

```rust
# fn main() {
let x = 5;
let y = 6;
println!("{}", x + y);
# }
```

Readers see only the two middle lines by default, with a small eye icon to reveal the hidden lines on demand.

**d) `mdbook test` — actually compiling/running your Rust snippets as tests.** This is the feature that matters most for a lessons+exercises book: it runs every non-ignored `rust`-tagged code block through `rustdoc`'s doctest machinery, the same way `cargo test --doc` tests doc comments. That means you can catch "the exercise solution doesn't actually compile anymore" as part of CI.

```sh
mdbook test
mdbook test path/to/book          # point at a book root explicitly
mdbook test -c "Ownership"        # test a single chapter by name or path
mdbook test -L target/debug/deps  # add a library search path if snippets `use` your own crate
```

Rules for what gets tested:
- Blocks tagged `rust` (or untagged, i.e. no language after the triple-backtick) are tested by default.
- `ignore` skips a block.
- Any language tag other than `rust`/none (e.g. `toml`, `bash`) is never tested.

**Known toolchain gotcha:** the standalone `mdbook test` command relies on your *default* rustup toolchain behaving like nightly in some edge cases around doctest flags; the Rust project's own internal docs now recommend wrapping it via their `xtask` tooling rather than calling `mdbook test` bare, specifically because it "only works reliably if your default toolchain is nightly" in some environments. For your own notes site on stable Rust this is very unlikely to bite you for simple exercises, but if `mdbook test` errors in a way that looks toolchain-related rather than code-related, that's the usual culprit — try `rustup run stable mdbook test` explicitly, or just don't rely on `mdbook test` as a hard CI gate and instead keep exercise solutions in a real Cargo crate you `cargo test` normally (see §7).

---

## 6. Key `book.toml` options worth knowing early

Minimal example after `mdbook init`:

```toml
[book]
title = "My Rust Notes"
authors = ["Marcin"]
language = "en"
src = "src"

[build]
build-dir = "book"
create-missing = true

[output.html]
default-theme = "navy"
preferred-dark-theme = "navy"
git-repository-url = "https://github.com/you/my-rust-notes"
edit-url-template = "https://github.com/you/my-rust-notes/edit/main/{path}"
```

Worth knowing about specifically:

- **`[book]` table** — `title`, `authors`, `description` (goes into HTML `<meta>`), `src` (default `src`, rarely changed), `language`.
- **`[rust] edition`** — sets the Rust edition assumed for playground/test code blocks (`"2015"`, `"2018"`, `"2021"`, `"2024"`). Set this explicitly if your exercises use recent edition features; otherwise mdBook's default may not match what you expect.
- **`[build]`**
  - `build-dir` — where rendered output goes (default `book`).
  - `create-missing` — if `true` (default), mdBook auto-creates a stub `.md` file for anything listed in `SUMMARY.md` that doesn't exist yet on disk. Convenient for stubbing your syllabus (write the whole `SUMMARY.md` first, then `mdbook build` once to generate empty files for every lesson/exercise).
  - `extra-watch-dirs` — as mentioned in §4, for watching files outside `src/`.
- **`[output.html]`** (the HTML renderer's own table)
  - `theme` — path to a folder of custom theme overrides if you want to fully reskin it.
  - `default-theme` / `preferred-dark-theme` — pick from mdBook's built-in themes (`light`, `rust`, `coal`, `navy`, `ayu`).
  - `git-repository-url` — adds a small repo link/icon to the top bar.
  - `edit-url-template` — adds a per-page "edit this page" link, using `{path}` as a placeholder — nice for a personal notes repo where you want quick access to the source Markdown.
  - `[output.html.search]` — built-in full-text search is on by default; this sub-table tunes `limit-results`, `use-boolean-and`, etc.
  - `[output.html.code.hidelines]` — lets you define hidden-line prefixes (§5c) for *other* languages beyond Rust's built-in `#` support, e.g. `python = "~"`.
  - `[output.html.playground]` — controls the Playground integration itself: `editable` (make *all* rust blocks editable by default, not just ones tagged `editable`), `copyable`, `copy-js`, `line-numbers`, `runnable` (set `false` to disable the run button globally instead of per-block).
- **`[preprocessor.X]` / `[output.Y]` tables** — this is how you wire in any third-party plugin (see §7). An empty `[preprocessor.links]` or `[preprocessor.index]` table is present by default in generated configs; those are mdBook's own built-in preprocessors (`links` resolves `{{#include}}` directives, `index` converts `README.md` → `index.html`).

---

## 7. Conventions and plugins for exercise-style content

mdBook's core Markdown doesn't have built-in admonitions/callouts, collapsible sections, or hidden-solution blocks — those come from either plain Markdown/HTML tricks or third-party preprocessors. For a Rustlings-style book, the practical options:

**a) Hidden solutions via `<details>`/`<summary>` (zero dependencies)**

mdBook renders raw HTML embedded in Markdown, so a collapsible "Show Solution" block needs nothing extra:

````markdown
<details>
<summary>Show solution</summary>

```rust
fn main() {
    let x: u32 = 1; // fixed
    println!("{}", x);
}
```

</details>
````

This is genuinely the most common pattern in hand-rolled mdBook exercise sites, precisely because it needs no preprocessor and works in every browser.

**b) `{{#include}}` for keeping exercise/solution code in sync with a real, compiling Cargo crate**

Rather than pasting Rust snippets into Markdown by hand (where they silently rot), mdBook's built-in `links` preprocessor supports pulling in external files:

```markdown
```rust
{{#include ../../exercises/ownership/src/main.rs}}
```
```

You can include line ranges or named "anchor" regions of a file too (`{{#include file.rs:10:20}}` or `{{#include file.rs:anchor_name}}`), which is the idiomatic way to keep a lesson's embedded snippet and a real, `cargo test`-able exercise crate as the *same source of truth*. This is exactly how The Rust Programming Language book itself keeps its code samples honest — every listing is `{{#include}}`d from a compiling project under `listings/`, not hand-copied.

**c) Common third-party preprocessors for callouts/diagrams/math** (install each with `cargo install`, then add a `[preprocessor.X]` table to `book.toml`):

- `mdbook-admonish` — styled callout boxes (`note`, `warning`, `tip`, etc.) via a fenced-code-like syntax. The most common choice for "beginner gotcha" or "hint" boxes in a lessons book.
- `mdbook-mermaid` — Mermaid diagrams (flowcharts, sequence diagrams) rendered client-side.
- `mdbook-katex` — LaTeX math rendering, if your notes ever need it.
- `mdbook-toc` — auto-generates an in-page table of contents per chapter.

Given the 0.5.0 architecture change mentioned in §1, when picking any of these, check that the version you install declares support for mdBook 0.5's preprocessor API (most actively maintained ones have already migrated — `mdbook-admonish` and `mdbook-mermaid` both have compatible releases).

**d) A concrete Rustlings-mirroring layout**, combining everything above:

```
my-rust-notes/
├── book.toml
├── exercises/                  # real Cargo workspace, `cargo test` runs it
│   ├── Cargo.toml
│   └── ownership/
│       ├── src/main.rs         # has the TODO/bug for the reader to fix
│       └── src/solution.rs
└── src/
    ├── SUMMARY.md
    └── ownership/
        ├── index.md            # short lesson prose + {{#include}} of a clean example
        ├── exercise.md         # {{#include}} of exercises/ownership/src/main.rs, editable block
        └── solution.md         # <details> collapsible, {{#include}} of solution.rs
```

---

## 8. Quick-reference: gotchas to watch for

1. **Files not in `SUMMARY.md` are silently excluded** from the build (§3) — mdBook warns but doesn't error.
2. **`create-missing = true`** (the default) will happily generate a pile of empty stub files if you typo a path in `SUMMARY.md` and then run `mdbook build` — check `git status` after your first build of a new `SUMMARY.md` to catch accidental stubs.
3. **`editable` code blocks are still sent to `play.rust-lang.org` to actually run** — they need network access from the reader's browser and only support what the Playground's sandbox supports (no filesystem, no arbitrary crates beyond what Playground has available, no `std::process`). Fine for teaching-sized snippets, not a substitute for a real `cargo test` exercise crate.
4. **`mdbook test` toolchain sensitivity** (§5d) — if it fails in a way unrelated to your code, suspect the nightly/stable mismatch before your snippet.
5. **Third-party preprocessor version compatibility with mdBook 0.5** (§1, §7c) — check before installing, especially if you followed an older tutorial that predates November 2025.
6. **`book/` (build output) shouldn't be hand-edited or committed** unless you're specifically deploying straight from it — treat it like `target/`.
7. **Nesting sidebar depth** — technically unlimited in `SUMMARY.md`, but the default theme visually degrades past ~3 levels; prefer flatter per-topic folders (§3) over deep hierarchies.

---

## Suggested next step

Run through §2–§4 once end-to-end on a throwaway folder (`mdbook init`, edit `SUMMARY.md` with one nested topic, `mdbook serve --open`) before wiring in `{{#include}}` and a real exercises crate — that loop takes under five minutes and makes the rest of this guide much more concrete.
