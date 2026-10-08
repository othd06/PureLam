
# The Standard Library of PureLam

The standard library currently comprises 7 modules (indented to show dependencies):
 - `std/combinators.plm`
   - `std/combinator_names.plm`
   - `std/birds.plm`
 - `std/base.plm`
   - `std/maths.plm`
     - `std/compounds.plm`
       - `std/monads.plm`

Note 1: any module that is dependent on a parent module, will also automatically import said parent module on import, so importing `std/monads.plm` makes the functionality of `std/compounds.plm`, `std/maths.plm`, and `std/base.plm` available as well without separately importing them.

Note 2: This document provides an overview of what is contained in the stdlib and what conventions are established, it is recommended after reading to look at the examples script in order to get a more tangible sense of how it is used in practice.

## The Combinators Module:

This standard library provides a large set of standard named [logical combinators](https://en.wikipedia.org/wiki/Combinatory_logic) and [fixed-point combinators](https://en.wikipedia.org/wiki/Fixed-point_combinator).

These are simple functions that are closed (which is to say, their lambda terms contain no free variables), filling a range of roles. As a system, these combinators are, by themselves, Turing-complete. That is to say, any PureLam program _can_ be written using only the combinators from the combinators module and nothing else (in fact, only the `S`, `K`, and `I` combinators are truly needed).

The full list of combinators provided is:
 - `I`
 - `K`
 - `S`
 - `B`
 - `C`
 - `W`
 - `Y`
 - `Z`
 - `U`
 - `Ph` (phi) (also known as `Sp` (S'))
 - `M`
 - `V`
 - `Th` (theta)
 - `KI`
 - `B1`
 - `J`
 - `D`
 - `R`

Note 1: These combinators are often referred to by different semantic names, aliases with these semantic names can also be loaded by instead using `std/combinator_names.plm`.

Note 2: It is possible you have either encountered combinators before or would like to learn about combinators in more detail using the amazing book [To Mock A Mockingbird](https://en.wikipedia.org/wiki/To_Mock_a_Mockingbird) by Raymond Smullyan, and other downstream resources such as the incredible talk [A Flock Of Functions](https://www.youtube.com/playlist?list=PLpkHU923F2XFWv-XfVuvWuxq41h21nOPK) which use bird names as aliases of function names. These can also be loaded by instead using `std/birds.plm`.

## The Combinator_Names and Birds Libraries:

These libraries provide the following aliases for the combinators defined in `std/combinators.plm`:
 - `I`:
   - `Identity` (names)
   - `Idiot` (birds)
 - `K`:
   - `Constant` (names)
   - `Kestrel` (birds)
 - `S`:
   - `Fuse` (names)
   - `Starling` (birds)
 - `B`:
   - `Compose` (names)
   - `Bluebird` (birds)
 - `C`:
   - `Flip` (names)
   - `Cardinal` (birds)
 - `W`:
   - `Join` (names)
   - `Warbler` (birds)
 - `Y`:
   - `Recurse` (names)
   - `Why` (birds)
 - `Z`:
   - `Zeledonia` (birds)
 - `U`:
   - `Turing` (birds)
 - `Ph`:
   - `Fork` (names)
   - `Phoenix` (birds)
 - `M`:
   - `Duplicate` (names)
   - `Mockingbird` (birds)
 - `V`:
   - `Apply2` (names)
   - `Vireo` (birds)
 - `Th`:
   - `Swap` (names)
   - `Thrush` (birds)
 - `KI`:
   - `Constant2` (names)
   - `Kite` (birds)
 - `B1`:
   - `Compose3` (names)
   - `Blackbird` (birds)
 - `J`:
   - `ContinueSwap` (names)
   - `Jay` (birds)
 - `D`:
   - `HalfFork` (names)
   - `Dove` (birds)
 - `R`:
   - `Swap3` (names)
   - `Robin` (birds)

## The Base Module:

This module provides the encoded values for `True` and `False` to represent boolean values and the function `Make-Pair` to make pairs of values as well as the following helper functions for each:
 - `If-Then` (booleans)
 - `And` (booleans)
 - `Or` (booleans)
 - `Not` (booleans)
 - `Nand` (booleans)
 - `Nor` (booleans)
 - `Xor` (booleans)
 - `Xnor` (booleans)
 - `Fst` (pairs)
 - `Snd` (pairs)

## The Maths Module:

This module (and others described below) relies on a conventional 'typeclass' encoding. This is a structure composed from nested pairs containing various different values and functions. The purpose of this is that a particular encoding can provide a set of base operations and then any other code can be polymorphic across different implementations (including user-written implementations). In particular, the set of primitive operations are not minimal, but instead designed to broadly capitalise on the differing efficiencies of a wide variety of potential encodings. Note, the use of the term 'typeclass' does not imply the existence of a type system in PureLam, which implements the **Untyped Lambda Calculus** but rather refers only to a meta-representational convention for encoding families of representations with shared behaviour.

The maths module in particular establishes a **_Num_** typeclass that can be understood as the following pair structure (read as dotted pairs in lisp-style syntax):
```lisp
(
    (
        Zero .
        (
            Repeat .
            Reserved
        )
    ) .
    (
        (
            (
                (Succ . Add)
                (Pred . Sub)
            ) .
            (
                (Div . IsZero) .
                (Sign . MinMax)
            )
        )
        (
            (
                (Eq . Cmp) .
                (Mul . Pow)
            ) .
            (
                (Mod . IsEven) .
                (Half . Double) .
            )
        )
    )
)
```

The module then provides eponymous functions to extract each of the above-listed primitive functions and values from a given Num as well as the following pre-defined non-primitive functions:
 - `Min`
 - `Max`
 - `Fact`
 - `Lt`
 - `Le`
 - `Ne`
 - `Ge`
 - `Gt`

Note: To use these functions, as with the primary functions, type the function name, followed by the concrete _Num_ typeclass instance (the num type) and then the arguments to the function.

And, finally, the module implements a concrete typeclass implementation named `Church-Nat` that implements Church-encoded natural numbers.

## The Compounds Module:

The compounds module also relies on the 'typeclass' convention described above in the maths module section.

The compounds module establishes one typeclass named **_List_** that can be understood as the following nested pair structure (read, again, as dotted pairs in lisp-style syntax):
```lisp
(
    (Nil . Cons) . 
    (
        (
            (Foldl . Foldr) .
            (Fold . IsNil) .
        )
        (
            (Head . Tail) .
            Reserved
        )
    )
)
```
Note: Fold is whichever of Foldl and Foldr is naturally least computationally complex for the given list implementation and can be used by algorithms that don't have a preferred direction.

As with the _Num_ typeclass, the compounds module provides eponymous functions to extract the base functions and values listed above.

It also provides these further non-primitive functions that operate on _Lists_:
 - `Filter`
 - `Map`
 - `Append`
 - `Reverse`
 - `Len` (Note: this must be provided a _List_ type then a _Num_ type)
 - `Drop` (Note: this must be provided a _List_ type then a _Num_ type)
 - `Take` (Note: this must be provided a _List_ type then a _Num_ type)
 - `Zip`
 - `ZipWith`
 - `Concat`
 - `ConcatMap`
 - `Partition`
 - `Replicate` (Note: this must be provided a _List_ type then a _Num_ type)

Note: As before, to use these functions (and the primitive functions also), type the name of the function followed by the concrete _List_ typeclass instance (the type) and then the arguments to the function.

Finally, the compounds module provides two concrete implementations of the _List_ typeclass named `Church-List` and `Scott-List` which implement Church-encoded and Scott-encoded lists respectively.

## The Monads Module:

Like the previous two modules, the monad module relies, again, on the typeclass convention.

The monad module establishes 3 typeclasses (again, written here as a set of nested lisp-style dotted pairs) named _Functor_:
```lisp
(
    (Fmap . Mapl) .
    (Reserved . Reserved) .
)
```
_Applicative_:
```lisp
(
    (Fmap . Mapl) .
    (
        Reserved_parent .
        (
            (Reserved . Reserved) .
            (
                (Pure . Apply) .
                (Seqr . Seql)
            )
        )
    )
)
```
and _Monad_:
```lisp
(
    (Fmap . Mapl) .
    (
        Reserved_parent .
        (
            (
                (Bind . Reserved).
                Reserved_parent
            ) .
            (
                (Return . Apply) .
                (Seqr . Seql)
            )
        )
    )
)
```
Note that each typeclass is an instance of the previous but with a reserved value replaced with some additional terms and each other reserved value replaced with reserved_parent (note: Return and Pure are aliases of each other in this specific case). This is how [inheritance](https://en.wikipedia.org/wiki/Inheritance_(object-oriented_programming))/[subtyping](https://en.wikipedia.org/wiki/Subtyping) is encoded in the typeclass convention of PureLam's stdlib.

Once again, the module provides eponymous extraction functions as well as the following compound functions (called as before, you know the drill by now):
 - `Unit` (_Functor_)
 - `Void` (_Functor_)
 - `LiftA` (_Functor_)
 - `LiftA2` (_Applicative_)
 - `LiftA3` (_Applicative_)
 - `Join` (_Monad_)
 - `Sequence` (_Applicative_) (Note: this must be provided a _List_ type then an _Applicative_/_Monad_ type)
 - `MapM` (_Applicative_) (Note: this must be provided a _List_ type then an _Applicative_/_Monad_ type)
 - `ForM` (_Applicative_) (Note: this must be provided a _List_ type then an _Applicative_/_Monad_ type)
 - `When` (_Applicative_)
 - `Unless` (_Applicative_)
 - `ReplicateM` (_Applicative_) (Note: this must be provided a _List_ type then an _Applicative_/_Monad_ type, and then a _Num_ type)
 - `FoldlM` (_Monad_) (Note: this must be provided a _List_ type then a _Monad_ type)
 - `FoldrM` (_Monad_) (Note: this must be provided a _List_ type then a _Monad_ type)
 - `FoldM` (_Monad_) (Note: this must be provided a _List_ type then a _Monad_ type)
 - `Forever` (_Monad_)

And defines the following concrete _Monad_ implementations:
 - Maybe
 - Either
 - IDMonad
 - List
 - Writer
 - Reader
 - State
 - Cont

referring to those monads as they exist standard-ly (that is to say, with their standard conventional semantics).

