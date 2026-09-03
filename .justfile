# Default recipe to display help
default:
    @just --list

# one-shot render to book/
@b:
    mdbook build

# Serve the book and open in browser + watch + live reload
@s:
    mdbook serve --open
