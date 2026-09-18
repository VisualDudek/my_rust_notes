## Introduction

**Mental model: `TryFrom` is `From` for conversions that can fail.**

`From`/`Into` say "this conversion always succeeds" (e.g. `u8` → `u32`). But turning a `String` into a `Status` isn't total — `"garbage"` doesn't map to any variant. Rust's type system forces you to be honest about that partiality by using `Result` in the signature, rather than silently panicking or returning some default variant. That's the core value: the compiler makes the caller handle the failure case, at the boundary where untrusted/unstructured data (user input, config, CLI args) enters your typed domain.

This is exactly the pattern in your code: `String` is the "raw" representation, `Status` is the validated domain type, and `TryFrom` is the checkpoint between them.

**The `&str` → delegate-to-`String` trick:**

```rust
impl TryFrom<&str> for Status {
    type Error = ParseError;

    fn try_from(value: &str) -> Result<Self, Self::Error> {
        value.to_string().try_into()
    }
}
```

> zobacz że pojawia się `type Error = ParseError;` w implementacji TryFrom, co jest wymagane dla konwersji, która może się nie powieść. Oraz `Result<Self, Self::Error>` w sygnaturze metody try_from wymusza obsługę błędu przez wywołującego.

Why this works and why it's idiomatic:
- `value.to_string()` builds an owned `String`.
- `.try_into()` here resolves to `TryFrom<String> for Status` (the blanket `impl<T, U> TryInto<U> for T where U: TryFrom<T>` gives you `TryInto` for free whenever `TryFrom` exists) — so it calls the impl you already wrote, with `Self::Error` inferred as `ParseError` from context.
- You avoid duplicating the match logic. One source of truth for "what counts as valid input," reused for both owned and borrowed strings.

The one cost: an extra allocation (`to_string()`) on every `&str` conversion, even though the `match` only ever needed a `&str` view (`as_str()`). For a config-parsing hot path that's likely irrelevant; if it ever matters, you'd instead extract the matching logic into a private `fn parse(s: &str) -> Result<Status, ParseError>` and have *both* `TryFrom<String>` and `TryFrom<&str>` call that, so neither allocates unnecessarily.

**Next step worth exploring:** once you have `TryFrom<&str>`, `s.parse::<Status>()` becomes available for free if you also implement `FromStr` — genuinely idiomatic Rust often prefers `FromStr` over `TryFrom<&str>` specifically for string-parsing types, since it plugs into `.parse()`, `str::parse`, and CLI arg parsing (`clap` uses it).