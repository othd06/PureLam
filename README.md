# PureLam

A small implementation of the **pure untyped lambda calculus** with a focus on remaining faithful to the calculus itself while still being pleasant to write programs in.

The core runtime semantics are exactly the untyped lambda calculus. Everything else: definitions, literal syntax, libraries (planned), and native interoperability is implemented as syntactic sugar or, where strictly necessary, as a minimal δ-rule bridge to/from the outside world.

## Design Goals

This project aims to be:

* **Pure** — computation is performed by the untyped lambda calculus.
* **Minimal** — the runtime contains as little language-specific machinery as possible.
* **Practical** — it should still be possible to write useful programs without manually writing enormous Church encodings every time (or forcing the reader to read them).

The guiding philosophy is:

#### Everything outside the pure abstract lambda calculus that can be expressed as syntax or macro expansion should be. The evaluator should only need to understand the lambda calculus itself.

## Features

Current implementation:

* Tokeniser
* Recursive-descent parser
* Capture-avoiding β-reduction
* α-conversion
* η-reduction
* AST canonicalisation
* Pretty printer
* Ordered macro expansion (`define`)
* File interpreter
* Interactive REPL

Planned:

* Standard library
* Church/native conversion primitives
* Literal syntax for common Church-encoded values
* Simple textual `include` system

## Usage

The PureLam interpreter has two modes:
 * The file interface
 * The REPL interface

To use the REPL interface call:
```text
PureLam repl
```
At which point the interpreter will wait for you to enter a line of code.
If you enter a definition the interpreter will print `-` to acknowledge this.
If you enter a term (that is to say, any code other than a definition) the interpreter will print the βη-reduction of your input (after expanding any macros).

To use the file interface call:
```text
PureLam <filepath>
```
At which point the interpreter will load the program and sequentially output the βη-reduction of each term in order.

It is intended to use the extension `.plm` for PureLam programs.

## Language

A Program consists of any number of definitions and terms.

Each definition/term is written on its own line (and therefore separated by newline).

A term can be a symbol, application, or abstraction (function).

Functions are written in the traditional lambda calculus notation:

```text
\x. x
```

Applications associate to the left:

```text
f x y
```

is equivalent to

```text
((f x) y)
```

β-reduction uses a normal-order (leftmost-outermost) reduction strategy.

Definitions are purely syntactic abbreviations:

```text
define identity \x. x

identity identity
```

Definitions are expanded before evaluation and are **not** part of the runtime semantics.

Definitions are ordered. A term/definition may reference any definition appearing earlier in the file but not itself or any later definition. This guarantees that macro expansion always terminates and avoids introducing recursive definitions into the language.

Recursion is therefore exclusively expressed in the traditional lambda-calculus way by using fixed-point combinators such as **Y**, rather than through special language features (of which there are none).

## Evaluation

Evaluation proceeds in stages.

1. Parse the source.
2. Expand all macro definitions.
3. Perform β-reduction to normal form.
4. Perform η-reduction to normal form.
5. Apply any callable conversion primitives.
6. Repeat steps 3-5 until no further conversions remain.

The evaluator performs capture-avoiding substitution using α-conversion where required.

Note: because the evaluator produces full βη-reduction and not just β-reduction, some outputs may be more reduced that you might initially expect. For example, the church numeral for 1: `\ s . \ z . s z` actually η-reduces the sub-expression `\z . s z` to merely `s` causing the numeral to present as the identity function `\ s . s`. This is correct in the sense that the church numeral for 1 is extensionally equivalent to the identity function however it may not match how you are used to seeing it expressed.

## Native Values

The evaluator supports native values through a deliberately tiny interoperability layer.

Native values are represented internally as symbols, allowing them to move through lambda expressions exactly like any other value.

The evaluator itself does not inspect or manipulate native values. The only operations that understand them are explicit conversion primitives.

These conversion primitives are pure function δ-rules that either accept a native value symbol and return the canonical church encoding, or take a canonical church encoding and return a native value symbol.

This keeps meaningful computation entirely within the lambda calculus while still allowing ergonomic interaction with the outside world.

Note: this does remove _strict_ alpha-equivalence (since conversion primitives attach semantic meaning to symbol values) however all symbols store an internal `instance` value that can be incremented to produce a distinct symbol without clobbering the value. This ensures that alpha-conversion still occurs smoothly and unproblematically where needed to ensure capture-free β-reduction. This also helps with readability as pure symbols retain their original name even after alpha-conversion, potentially followed by a `'n` suffix. 

## Standard Library

The intention is for almost all useful functionality to live in the standard library rather than the interpreter.

Examples include:

* Church booleans
* Church numerals
* Arithmetic
* Pairs
* Lists
* Fixed-point combinators
* Higher-order list operations
* Common combinators

These are ordinary source files written in the language itself.

## Philosophy

This project deliberately avoids extending the lambda calculus with language features such as:

* recursive definitions
* built-in arithmetic
* pattern matching
* mutable state
* type systems

Instead, the interpreter provides a small, faithful runtime together with enough syntax and tooling to make programming in the pure lambda calculus practical.

The goal is not to create a semantically distinct functional programming language.

The goal is to create a pleasant implementation of the **pure untyped lambda calculus**.

## Status

This project is currently under active development.

The core evaluator is implemented, with work continuing on the runtime interface, standard library, and native conversion primitives.
