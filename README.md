
# PureLam

## Introduction:

PureLam is an implementation of the **pure untyped lambda calculus** in Nim with a core focus on remaining both semantically faithful to the original 1936 calculus whilst also being usable to program in.

The core runtime semantics are exactly the untyped lambda calculus. Everything else: definitions, literal syntax, libraries, and native interoperability is implemented as syntactic sugar or, where strictly necessary, as a minimal δ-rule bridge to/from the outside world.

See [PHILOSOPHY](PHILOSOPHY.md) for more detail about the specific language philosophy.

If this is your first introduction to the Untyped Lambda Calculus. Welcome. Also, a README probably isn't a great place to try and learn it; go watch [A Flock Of Functions](https://youtube.com/playlist?list=PLpkHU923F2XFWv-XfVuvWuxq41h21nOPK&si=guBgzzwwCz9ONzyf) then come back and read this. You'll love it. Thank me later.

## Features/Current Status:

PureLam is currently in pre-release for 1.0.0. This means that features have been frozen however testing and documentation/examples are still being finalised for 1.0.0. It is currently intended that there will be no 2.0.0 (ie, it is expected that there will be no need to introduce a breaking change).

Current features include:
* Tokeniser
* Comments
* Recursive-descent parser
* Capture-avoiding β-reduction
* α-conversion
* η-reduction
* AST canonicalisation
* Pretty printer
* Ordered preprocessor expansion of shorthands
* File interpreter
* Interactive REPL
* Encoded/native conversion primitives for booleans, church numerals for naturals, pairs, church lists, ASCII characters, scott lists, and strings
* Literal syntax for common encoded values
* A basic module system
* Macro-based inputs
* ` notation for automatic conversion of native values to encodings
* Standard library

## Build/Installation

The entire interpreter is a single executable into which the standard libraries are embedded. Therefore installation is as simple as placing this executable either in the folder in which your code resides or in your system path.

Note: during pre-release stages new builds are not provided meaning that it is necessary to build from source.

In order to build from source you must have a version of the Nim compiler. The source code has been written against Nim 2.2.4 however I suspect that any 2.x version will work equally well (if you encounter issues please submit a GitHub issue).

There are no other dependencies beyond the Nim standard library which is included in the compiler.

In order to compile, clone the repository and run the following command in the top level directory for release builds:
```
nim c -d:release --out:PureLam src/lambda_calc.nim
```
Or for debug builds:
```
nim c --out:PureLam src/lambda_calc.nim
```

Note that since the standard libraries are embedded in the executable it is necessary to rebuild the executable if you have made changes to the standard libraries, or to import your changed version separately via its local filepath rather than via `"std/..."`.

## Usage:

There are two ways to use the PureLam interpreter:
  * The file interpreter
  * The REPL (Read Eval Print Loop)

### The File Interpreter:

The customary extension for PureLam files is `.plm`.
To run a file you simply call:
```
PureLam <your filename>.plm
```
in your command line terminal.

### The REPL:

You can also write programs directly in the PureLam REPL.

This is a command line interface that evaluates programs line by line as you write them rather than saving them.

To enter the REPL you simply call:
```
PureLam repl
```
in your command line terminal.

Additionally, the REPL has two additional commands `quit` and `reset` each of which can be written in place of a PureLam line of code in order to exit out of the REPL environment and to clear the current program respectively.

## [Evaluation Strategy](https://en.wikipedia.org/wiki/Reduction_strategy#Lambda_calculus):

Note: If this doesn't make sense yet, read the language syntax section and come back.

The language currently uses full normal order evaluation with beta-delta reduction followed by full eta-reduction.

In future it is intended that there will be command line flags to expose options such as alternative evaluation strategies (full call-by-value, eager evaluation, call-by-need, call-by-name, etc...) or the ability to toggle off eta-reduction.

In future it is also intended that the default strategy will diverge from normal order evaluation in that it will use optimisations such as call-by-value and normalisation-by-evaluation when it can ensure that this will not produce a different result than normal order evaluation or result in the need for a call stack (which can, of course, run out). This means that any code you write now will always evaluate to the same output on any future version however performance characteristics may change unless they are run specifically reverting to full normal order evaluation using command line flags which may matter for specific research about the performance of different expressions under normal order evaluation.

Note: because the evaluator currently produces full βη-reduction and not just β-reduction, some outputs may be more reduced than you might initially expect. For example, the church numeral for 1: `\ s . \ z . s z` actually η-reduces the sub-expression `\z . s z` to merely `s` causing the numeral to present as the identity function `\ s . s`. This is correct in the sense that the church numeral for 1 is extensionally equivalent to the identity function however it may not match how you are used to seeing it expressed.

## The Language Syntax:

Note: If you are already familiar with writing lambda calculus terms and want a TLDR for this section, one can be found just below however it is recommended you still read the whole section to understand fully.

A program consists of any number of lines each of which may do one of 3 things:
  * Be a Term
  * Define a Shorthand
  * Import a Module

Each of these is terminated by a newline meaning you write one per line (excluding blank lines).

Additionally, there are comments and some specialised syntax sugar.

### Terms:

Terms in PureLam are ordinary lambda calculus terms. A term may be any one of 3 (technically 5) things:
  * Variables
  * Abstractions
  * Applications
  * (Impure Symbols)
  * (IO Delta runes)

Variables are simply written as an identifier (symbol) and is any string of characters starting with an alphabetical character and containing only alphanumeric characters and/or the character '-'.

A free variable is simply referred to by the name it is given. Variables may be bound using an abstraction.

Abstractions are ordinary lambda abstractions. These are analogous to functions. They are written as follows:
```
\<variable to bind>.<term in which to bind the variable>
```
Where the variable that is bound is analogous to a function input and the term in which it is bound is analogous to the function body.

For functions with multiple inputs, the convention within the lambda calculus is to use [Currying](https://en.wikipedia.org/wiki/Currying) which is written as follows:
```
\<variable to bind as first arg>.\<variable to bind as snd arg>.<term in which to bind the variables>
```
Note: In future versions it will be possible to use λ in place of \ however these will mean the same thing.

Abstractions can be used in applications which look as follows:
```
(<some abstraction>) <some input>
```
Where the entire value is then evaluated to the result of replacing each instance of the variable bound by the abstraction in the body of the abstraction with the input.

Note: for inputs that are longer than a single variable or abstraction (since abstractions can be applied to abstractions) it is necessary to enclose the input in brackets (parentheses).

PureLam makes two extensions to the 1936 calculus and these are impure symbols and IO delta runes. These technically belong in the lambda-delta calculus of 1941 rather than the 1936 calculus however they are necessary to ensure usability and are deliberately given restricted semantics to ensure behaviour remains close to the 1936 calculus instead.

Impure symbols are any value that is not a variable or an abstraction. These currently include:
  * Natural numbers (written as ordinary decimal numbers)
  * Characters (written as a single ASCII character enclosed in 'single quotes')
  * Strings (written as a string of ASCII characters enclosed in "double quotes")
  * Church-y Lists (written as a series of terms enclosed by \[square brackets] and separated by commas (,) )
  * Scott-y Lists (written as a series of terms enclosed by \{curly brackets} and separated by commas (,) )
  * Pairs (written as two terms enclosed by \<angle brackets> and separated by a comma (,) )
  * Booleans (written as `#t` or `#f`)

None of these impure symbols can be computed on however they are valid inputs to IO delta runes. The current IO delta runes are:
  * io-church-to-int
  * io-int-to-church
  * io-church-to-pair
  * io-pair-to-church
  * io-church-to-bool
  * io-bool-to-church
  * io-church-to-list
  * io-list-to-church
  * io-scott-to-list
  * io-list-to-scott
  * io-church-to-char
  * io-char-to-church
  * io-scott-to-string
  * io-string-to-scott

Each rune acts as a named abstraction which accepts as an input either an impure symbol or a [canonical encoding](https://en.wikipedia.org/wiki/Lambda_calculus#Encoding_datatypes) and returns the symbol and/or encoding with which it corresponds.

The currently supported encodings are (in order of the impure symbols as written above, and included again here for readability):
  * Natural numbers ⇔ [Church Numerals](https://en.wikipedia.org/wiki/Church_encoding#Church_numerals)
  * Characters ⇔ [ASCII](https://www.asciitable.com/) [Church Numerals](https://en.wikipedia.org/wiki/Church_encoding#Church_numerals)
  * Strings ⇔ [Scott Lists](https://en.wikipedia.org/wiki/Mogensen%E2%80%93Scott_encoding#Lists) of [ASCII](https://www.asciitable.com/) [Church Numerals](https://en.wikipedia.org/wiki/Church_encoding#Church_numerals)
  * Church-y Lists ⇔ [Church Lists](https://en.wikipedia.org/wiki/Church_encoding#Church_lists_%E2%80%93_right_fold_representation)
  * Scott-y Lists ⇔ [Scott Lists](https://en.wikipedia.org/wiki/Mogensen%E2%80%93Scott_encoding#Lists)
  * Pairs ⇔ [Church Pairs](https://en.wikipedia.org/wiki/Church_encoding#Church_pairs)
  * Booleans ⇔ [Church Booleans](https://en.wikipedia.org/wiki/Church_encoding#Church_Booleans)

Each term you write will be printed, in order, when the program evaluates (assuming the term itself, and those before it, effectively compute and [halt](https://en.wikipedia.org/wiki/Halting_problem))

### Shorthand Definitions:

You can define a shorthand with either of the keywords: `define` or `define-unsafe`.

Currently these operate identically however it is planned in future versions that they will diverge so while it is advised to use `define` generally, only `define-unsafe` is guaranteed to behave identically in future versions so please see the note at the end of this sub-subsection to determine which you should use specifically.

In general, definitions work like macros in that they are preprocessor directives.

To define a shorthand you use one of the two keywords immediately followed by the name of the shorthand (which can be any identifier as you might use for a variable name) and then, directly afterwards (without any symbol like `=`), the body of the shorthand.

Doing so will result in every instance of the name of the shorthand in later lines of the program (earlier lines will not be affected, including within the shorthand body itself since shorthands cannot be defined recursively) to be replaced with the body of the function allowing for features such as named functions and values.

In future the keyword `define` will define shorthands that are safe in the sense that they are capture free meaning that no free (unbound) variable in the shorthand body will be allowed to become captured when copying the body into wherever it is used. Since this is not currently implemented for shorthands (although obviously capture-free substitution is implemented for function applications don't worry), it is recommended to be wary of such situations however if you, in fact, rely on capture of free variables within your shorthand then it is advised to use `define-unsafe` for forward-compatibility.

### Module Imports:

You can import a module with either of the keywords: `io-include` or `io-include-permissive`.

The former will throw an error if you attempt to import a module twice. This is useful for cycle detection. The latter will silently not import any modules that are already imported. This is useful when you want to define two modules which share some dependency and may be used together however it will result in mutually dependent modules that may silently break rather than loudly failing.

Currently inclusion is equivalent to C's textual include system however it is planned for later versions that modules will be able to include private definitions which are not shared with any program or module that imports it.

After the include keyword, you must provide a string denoting the relative filepath of the module being imported. The exception to this are the standard libraries which, as stands, are:
  * std/combinators
  * std/birds
  * std/combinator-names
  * std/base
  * std/maths
  * std/compounds
  * std/monads

And you can read more about them in [STDLIB](STDLIB.md).

### Comments:

Comments are all multi-line style comments and are bookended (on both ends) with semicolons (;). It is possible to use blocks of semicolons to denote the "strength" of a comment with higher strength comments being able to embed lower strength comments.

For instance, if you have some ordinary comments in your code using strength 1 comments bookended by single semicolons, then you can still comment out the entire block of code using double semicolons (;;) to form a strength 2 comment that will not be interfered with by the embedded strength 1 comments.

Since comments are multi-line, it is also possible to comment-out newlines. This is the only way to define multi-line terms within PureLam.

### Syntax Sugar:

Currently the only syntax sugar is quote notation. Quote notation consists of using the character `` ` `` before an **impure symbol**. Doing so will automatically replace the symbol as follows:
```
<impure symbol> ⇒ (<IO delta rune> <impure symbol>)
```
Where the IO delta rule in question is whichever one converts that particular impure symbol to its canonical representation as defined in the Terms section.

### Misc:

Additionally, any instance of the symbol `io-input` must be followed by a string and will be used at the preprocessor stage for input. The string following the instance of `io-input` will be printed by the preprocessor after which it will wait for the user to type some input. This input will be replaced in place of whatever the original input was to produce a very rudimentary form of input. Again, this is an extension beyond the 1936 calculus that is required for usability.

## TLDR Syntax:

  * The Greek letter lambda is indicated using `\` but will also support `λ` in **future versions**.
  * All terms are newline terminated.
  * PureLam contains impure symbols for pairs, lists, booleans, naturals, chars, and strings.
  * These impure symbols cannot be computed on and can only be translated to and from their canonical encodings using a limited set of delta runes that only act as a bridge around IO.
  * You can automatically convert an impure symbol to its encoding by prefixing it with `` ` ``
  * The standard way to define a shorthand is with `define` followed by the name and then the body, rather than using some sort of `=` syntax.
  * `define` is currently not capture-free but will be in future versions so if you don't want this use `define-unsafe`
  * Comments are multi-line style beginning and ending with semicolons whereby blocks containing higher numbers of semicolons can bookend comments that use lower numbers of semicolons.
  * PureLam does not include `\x y z.` as syntax sugar for `\x.\y.\z.` for stylistic reasons.


## Examples:

Currently there are no examples.

By the release of 1.0.0 there will be a directory labelled examples within the repository in which you will be able to look for examples.

For now I recommend simply reading the stdlibs.

## Contributing:

The roadmap as it currently exists is just managed through the GitHub issues of this repository.

Additionally please feel free to submit any of your own issues for bugs, feature requests, etc...

Please note that if you do submit an issue requesting a feature then I may choose to close it without accepting it if I deem (as maintainer and BDFL) that it would violate [the core philosophy of PureLam](PHILOSOPHY.md).

All PRs which are accepted to be worked on are tagged with the label `accepting PRs`. It goes without saying, please don't add or remove this label unless you are a maintainer (you aren't). If you are looking to contribute code, these are the issues for which, well, PRs will be accepted.

Regarding Copyright, unless stated otherwise (such at the start of the text of LICENCE.md), all copyrights within the project belong to the contributor whom it is indicated by the commit history contributed that piece of code however the act of contributing said code is treated as providing that code under the [licence](LICENCE.md) of the project.
