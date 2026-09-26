# Summary


# Part I: Fundamentals

- [Chapter 1](./chapter_1.md)
    - [Can a Rust Slice Represent Filtered Data?](./ch1/can_slice_represent_filtered_data.md)
    - [Follow-up: `Vec<&T>` for Filtered Data](./ch1/follow_up_for_filtered_data.md)
    - [Trait with Same Body for Different Types](./ch1/trait_same_body_diff_types.md)
    - [`self` vs. `Self`](./ch1/self_vs_Self.md)
    - [`&String` to `&str` via Deref Coercion](./ch1/String_to_str_Deref.md)
    - [follow up Deref Mental Model](./ch1/Deref_mental_model.md)
    - [Autoderef/Autoref in Method Resolution](./ch1/autoderef_autoref_in_method_resolution.md)
    - [Follow up: Autoderef/Autoref in Method Resolution](./ch1/follow_up_autoderef_1.md)
    - [Associated type mental model](./ch1/assoc_type_mental_model.md)
    - [Trait associated type - notes](./ch1/assoc_type.md)
    - [Use Case for Associated `Output`](./ch1/usecase_for_assoc_Output.md)
    - [Is Even generic function](./ch1/is_even_generic_fn.md)
    - [`impl` generic From Trait](./ch1/impl_generic_from.md)
    - [Idiomatic `From` Trait Implementations](./ch1/idiomatic_From_trait.md)
    - [`&x` vs `&*x` (let coercion do the work)](./ch1/let_coercion_do_the_work.md)
    - [Where `&String` Points](./ch1/where_ref_String_points.md)
    - [Match Ergonomics](./ch1/match_ergonomics.md)
    - [Mental Model: `TryFrom` that can fail](./ch1/mental_model_TryFrom.md)
    - [Basics of `Error::source()`](./ch1/basics_of_error_source.md)
    - [Closure passed to `filter` takes a reference](./ch1/closure_filter_take_ref.md)
    - [Why Both `.iter()` and `IntoIterator`?](./ch1/why_both_iter()_IntoIterator.md)
    - [mock]()
- [Chapter 2]()
    - [The `Rc` Type Explained for a 5-Year-Old](./ch2/explain_5yo_Rc.md)
    - [`Rc` vs Standard Ownership in Rust](./ch2/Rc_vs_standard_ownership.md)
    - [The `RefCell` Type Explained for a 5-Year-Old](./ch2/explain_5yo_RefCell.md)
    - [`Rc` + `RefCell` Pattern](./ch2/pattern_Rc_RefCell.md)
    - [Static Function Arguments: `&[i32]` vs. `&'static [i32]`](./ch2/static_fn_arg.md)
- [Coming Soon]()

# Other

- [Introduction to mdBook](./mdbook-getting-started.md)