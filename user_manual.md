# Introduction

This is the user manual for the AletheLF checker (alfc), an efficient and extensible tool for checking proofs of Satisfiability Modulo Theories (SMT) solvers.

## Building alfc

The source code for alfc is available here: https://github.com/ajreynol/AletheLF-tc.
To build alfc, run:
```
mkdir build
cd build
cmake ..
```
The `alfc` binary will be available in `build/src/`.

### Debug build

By default, the above will be a production build of `alfc`. To build a debug version of `alfc`, that is significantly slower but has assertions and trace messages enabled, run:
```
mkdir build -DCMAKE_BUILD_TYPE=Debug
cd build
cmake ..
```
The `alfc` binary will be available in `build/src/`.

## Command line interface of alfc

`alfc` can be run from the command line via:
```
alfc <option>* <file>
```
The set of available options `<option>` are given in the appendix. Note the command line interface of `alfc` expects exactly one file (which itself may reference other files via the `include` command as we will see later). The file and options can appear in any order.

The ALF checker will either emit an error message indicating:
- The kind of failure (type checking, proof checking, lexer error),
- The line and column of the failure.
Otherwise, the ALF checker will print `success` when it finished parsing all commands in the file or encounters and `exit` command.
Further output can be given by user-provided `echo` commands.

### Streaming input to the ALF checker

The `alfc` binary accepts input piped from stdin. The following are all equivalent ways of running `alfc`:
```
% alfc <file>
% alfc < <file>
% cat <file> | alfc
```

## Overview of Features

The AletheLF (ALF) language is an extension of SMT-LIB version 3.0 for defining proof rules and writing proofs from SMT solvers. Since ALF is closely based on the SMT-LIB format, ALF files typically are given the suffix `*.smt3`.

The core features of the ALF language include:
- Support for SMT-LIB version 3.0 syntax for defining theory signatures.
- Support for associating syntactic categories (as specified by SMT-LIB e.g. `<numeral>`) with types.
- A set of commands for specifying proofs (`step`, `assume`, and so on), whose syntax closely follows the Alethe proof format (for details see []).
- A command `declare-rule` for defining proof rules.

The ALF checker alfc extends this language with several features:
- A library of operations (`alf.add`, `alf.mul`, `alf.concat`, `alf.extract`) for performing computations over values.
- A command `program` for defining side conditions as ordered list of rewrite rules.
- A command `declare-oracle-fun` for user-provided oracles, that is, functions whose semantics are given by external binaries. Oracles can be used e.g. for modular proof checking.
- Commands for file inclusion (`include`) and referencing (`reference`). The latter command can be used to specify the name of a `*.smt3` that the proof is associated with.
- Support for compiling ALF signatures to C++ code that can be integrated into `alfc`.

In the following sections, we review these features in more detail. A full syntax for the commands is given at the end of this document.


# Declaring theory signatures

In ALF as in SMT-LIB version 3.0, a common BNF is used to specify terms, types and kinds.
In this document, a *term* may denote an ordinary term, a type or a kind.
Terms are composed of applications, several built-in operators of the language (e.g. for performing computations, see [computation](#computation)), and three kinds of atomic terms (*constants*, *variables*, and *parameters*) which we will describe in the following.
A *function* is an atomic term having a function type.
The standard `let` binder can be used for specifying terms that contain common subterms, which is treated as syntax sugar.

As mentioned, the core language of ALF does not assume any definitions of standard SMT-LIB theories.
Instead, SMT-LIB theories may defined as ALF signatures.
Specifically, the ALF language has the following builtin expressions:
- `Type`, denoting the kind of all types,
- `->`, denoting the function type,
- `_`, denoting (higher-order) function application,
- `Bool`, denoting the Boolean type,
- `true` and `false`, denoting values of type `Bool`.

> The core logic of the ALF checker also uses several builtin types (e.g. `Proof` and `Quote`) which define the semantics of proof rules. These types are intentionally left hidden from the user. Details on these types can be found throughout this document. More details on the core logic of the ALF checker can be found here [].

In the following, we informally write BNF categories `<symbol>` to denote an SMT-LIB version 3.0 symbol, `<term>` to denote an SMT-LIB term and `<type>` to denote a term whose type is `Type`, `<typed-param>` is a pair `(<symbol> <type>)` that binds `<symbol>` as a fresh parameter of the given type.

The following commands are supported for declaring and defining types and terms, most of which are taken from SMT-LIB version 3.0:
- `(declare-const <symbol> <type>)` declares a constant named `<symbol>` whose type is `<type>`.
- `(declare-fun <symbol> (<type>*) <type>)` declares a constant named `<symbol>` whose type is given by the argument types and return type.
- `(declare-sort <symbol> <numeral>)` declares a new type named `<symbol>` whose kind is `(-> Type^n Type)` if `n>0` or `Type` for the provided numeral `n`.
- `(declare-type <symbol> (<type>*))` declares a new type named `<symbol>` whose kind is given by the argument types and return type `Type`.
- `(define-const <symbol> <term>)` defines `<symbol>` to be the given term.
- `(define-fun <symbol> (<typed-param>*) <type> <term>)` defines `<symbol>` to be a lambda term whose arguments, return type and body and given by the command, or the body if the argument list is empty.
- `(define-sort <symbol> (<symbol>*) <type>)` defines `<symbol>` to be a lambda term whose arguments are given by variables of kind `Type` and whose body is given by the return type, or the return type if the argument is empty.
- `(define-type <symbol> (<type>*) <type>)` defines `<symbol>` to be a lambda term whose kind is given
- `(declare-datatype <symbol> <datatype-dec>)` defines a datatype `<symbol>`, along with its associated constructors, selectors, discriminators and updaters.
- `(declare-datatypes (<sort-dec>^n) (<datatype-dec>^n))` defines a list of `n` datatypes for some `n>0`.
- `(reset)` removes all declarations and definitions and resets the global scope.

The ALF language contains further commands for declaring symbols that are not standard SMT-LIB version 3.0:
- `(declare-var <symbol> <type>)` declares a variable named `<symbol>` whose type is `<type>`.
- `(declare-consts <literal-category> <type>)` declares the class of symbols denoted by the literal category to have the given type.

> Variables are internally treated the same as constants by the ALF checker, but are provided as a separate category, e.g. for user signatures that wish to distinguish universally quantified variables from free constants.

> Symbols cannot be overloaded in the ALF checker.

### Basic Declarations

```
(declare-sort Int 0)
(declare-const c Int)
(declare-const f (-> Int Int Int))
(declare-fun g (Int Int) Int)
(declare-fun P (Int) Bool)
```

Since alfc does not assume any builtin definitions of SMT-LIB theories, definitions of standard symbols (such as `Int`) may be provided in ALF signatures. In the above example, `c` is declared to be a constant (0-ary) symbol of type `Int`. The symbol `f` is a function taking two integers and returning an integer.

Note that despite using different syntax in their declarations, the types of `f` and `g` in the above example are identical.

> In alfc, all functions are unary. In the above example, `(-> Int Int Int)` is internally treated as `(-> Int (-> Int Int))`. Correspondingly, applications of functions are curried, e.g. `(f a b)` is treated as `((f a) b)`, which in turn can be seen as `(_ (_ f a) b)` where `_` denotes higher-order function application.

### Definitions

```
(declare-const not (-> Bool Bool))
(define-fun id ((x Bool)) Bool x)
(define-fun notId ((x Int)) Bool (not (id x)))
```

In the example above, `not` is declared to be a unary function over Booleans. Two defined functions are given, the first being an identity function over Booleans, and the second returning the negation of the first.

Since `define-fun` commands are treated as macro definitions, in this example, `id` is mapped to the lambda term whose SMT-LIB version 3 syntax is `(lambda ((x Bool)) x)`.
Furthermore, `notId` is mapped to the lambda term `(lambda ((x Bool)) (not x))`.
In other words, the following file is equivalent to the one above after parsing:
```
(declare-const not (-> Bool Bool))
(define-fun id ((x Bool)) Bool x)
(define-fun notId ((x Int)) Bool (not x))
```

## Polymorphic types

```
(declare-sort Int 0)
(declare-sort Array 2)
(declare-const a (Array Int Bool))

(define-sort IntArray (T) (Array Int T))
(declare-const b (IntArray Bool))
```

In the above example, we define the integer sort and the array sort, whose kind is `(-> Type Type Type)`.

Note the following declarations all generate types of the same kind:

```
(declare-sort Array_v1 2)
(declare-type Array_v2 (Type Type))
(declare-const Array_v3 (-> Type Type Type))
```

## Variable and implicit annotations

The ALF language uses the SMT-LIB version 3.0 attributes `:var <symbol>` and `:implicit` in term annotations for naming arguments of functions and specifying they are implicit.

```
(declare-sort Int 0)
(declare-const eq (-> (! Type :var T) T T Bool))
(define-fun P ((x Int) (y Int)) Bool (eq Int x y))
```

The above example declares a predicate `eq` whose first argument is a type, that is given a name `T`. It then expects two terms of type `T` and returns a `Bool`. In the definition of `P`, this predicate is applied to two variables, where the type `Int` must be explicitly provided.

```
(declare-sort Int 0)
(declare-const = (-> (! Type :var T :implicit) T T Bool))
(define-fun P ((x Int) (y Int)) Bool (= x y))
```

In contrast, the above example declares a predicate `=` where the type of the arguments is implicit (this corresponds to the SMT-LIB standard definition of equality). In the definition of `P`, the type of the arguments `Int` does not need to be provided.

We call `T` in the above definitions a *parameter*. The free parameters of the return type of an expression should be contained in at least one non-implicit argument. In particular, the following declaration is malformed, since the return type of `f` cannot be inferred from its arguments:


```
(declare-sort Int 0)
(declare-const f (-> (! Type :var T :implicit) Int T))
```

> Internally, `(! T :var t)` is syntax sugar for the type `(Quote t)` where `t` is a parameter of type `T` and `Quote` is a distinguished type of kind `(-> (! Type :var U) U Type)`. When type checking applications of functions of type `(-> (Quote t) S)`, the parameter `t` is bound to the argument the function is applied to.

> Internally, `(! T :implicit)` drops `T` from the list of arguments of the function type we are defining.

## Requires annotations

Arguments to functions can also be annotated with the attribute `:requires (<term> <term>)` to denote a condition under which the

```
(declare-sort Int 0)
(declare-const BitVec (-> (! Int :var w :requires ((alf.is_neg w) false)) Type))
```
The above declares the integer sort and the bitvector sort that expects a non-negative integer `w`.

In detail, the first argument of `BitVec` is an integer sort, which is named `w` via `:var`.
The second annotation indicates that `(alf.is_neg w)` must evaluate to `false`, where note that `alf.is_neg` returns `true` if and only if its argument is a negative numeral (for details, see [computation](#computation)).

> Internally, `(! T :requires (t s))` is syntax sugar for `(alf.requires t s T)` where `alf.requires` is an operator that evalutes to its third argument if and only if its first two arguments are equivalent (details on this operator are given in [computation](#computation)). Furthermore, the function type `(-> (alf.requires t s T) S)` is treated as `(-> T (alf.requires t s S))`. The ALF checker rewrites all types of the former to the latter.

## Declarations with attributes

The ALF language supports term annotations on declared functions, which can allow the user to treat a declared function as being variadic, i.e. taking an arbitrary number of arguments. These annotations are:
- `:right-assoc` (resp. `:left-assoc`) denoting that the term is right (resp. left) associative,
- `:right-assoc-nil <term>` (resp. `:left-assoc-nil <term>`) denoting that the term is right (resp. left) associative with the given nil terminator,
- `:list`, denoting that the term should be treated as a list when appearing as a child of an application of a right (left) associative operator,
- `:chainable <term>` denoting that the arguments of the term are chainable using the given (binary) operator,
- `:pairwise <term>` denoting that the arguments of term are treated pairwise using the given (binary) operator.

### Right/Left associative

```
(declare-const or (-> Bool Bool Bool) :right-assoc)
(define-fun P ((x Bool) (y Bool) (z Bool)) Bool (or x y z))
(define-fun Q ((x Bool) (y Bool)) Bool (or x y))
(define-fun R ((x Bool)) (-> Bool Bool) (or x))
```

In the above example, `(or x y z)` is syntax sugar for `(or x (or y z))`.
The term `(or x y)` is not impacted by the annotation `:right-assoc` since it has fewer than 3 children.
The term `(or x)` is also not impacted by the annotation, and denotes the partial application of `or` to `x`, whose type is `(-> Bool Bool)`.

```
(declare-const and (-> Bool Bool Bool) :left-assoc)
(define-fun P ((x Bool) (y Bool) (z Bool)) Bool (and x y z))
```

Similarly, in the above example, `(and x y z)` is syntax sugar for `(and (and x y) z)`.

Note that the type for right and left associative operators is typically `(-> T T T)` for some `T`.

### Right/Left associative with nil terminator

ALF supports a variant of the aforementioned functionality where a nil terminator is provided.

```
(declare-const or (-> Bool Bool Bool) :right-assoc-nil false)
(define-fun P ((x Bool) (y Bool) (z Bool)) Bool (or x y z))
(define-fun Q ((x Bool) (y Bool)) Bool (or x y))
(define-fun R ((x Bool) (y Bool)) Bool (or x))
```

In the above example, `(or x y z)` is syntax sugar for `(or x (or y (or z false)))`,
`(or x y)` is syntax sugar for `(or x (or y false))`,
and `(or x)` is syntax sugar for `(or x false)`.

The advantage of right (resp. left) associative operators nil terminators is that the terms they specify are unambiguous, in constrast to operators without nil terminators.
In particular, note the following example:

```
(declare-const or (-> Bool Bool Bool) :right-assoc-nil false)
(define-fun P ((x Bool) (y Bool) (z Bool)) Bool (or x (or y z)))
(define-fun Q ((x Bool) (y Bool) (z Bool)) Bool (or x y z))
```

If `or` would have been marked `:right-assoc`, then the definition of both `P` and `Q` would be `(or x (or y z))` after desugaring.
In contrast, marking `or` with `:right-assoc-nil false` leads to the distinct terms `(or x (or (or y z) false))` and `(or x (or y (or z false)))` after desugaring.

Right and left associative operators with nil terminators also have a relationship with list terms (as we will see in the following section), and in computational operators.

Note that the type for right and left associative operators with nil terminators is typically `(-> T T T)` for some `T`, where their nil terminator has type `T`.

### List

Atomic terms can be marked with the annotation `:list`. Conceptually, this annotation marks that the term should be treated as a list of arguments when it occurs as an argument of a right (left) associative operator with a nil element. Note the following example:

```
(declare-const or (-> Bool Bool Bool) :right-assoc-nil false)
(define-fun P ((x Bool) (y Bool)) Bool (or x y))
(define-fun Q ((x Bool) (y Bool :list)) Bool (or x y))
(declare-const a Bool)
(declare-const b Bool)
(define-const Paab Bool (P a (or a b)))
(define-const Qaab Bool (Q a (or a b)))
```

In the above example, note that `or` has been marked `:right-assoc-nil false`.
As before, the definition of `P` is syntax sugar for `(or x (or y false))`.
In contrast, the definition of `Q` is simply `(or x y)`, since `y` has been marked with `:list`.
Conceptually, our definition of `Q` denotes that we expect to `y` to be treated as the tail of `or` in the body of `Q`.

Then, `P` and `Q` are both applied to the pair of arguments `a` and `(or a b)`.
In the former (i.e. `Paab`), the definition is equivalent after desugaring to `(or a (or (or a (or b false)) false))`, whereas in the latter (i.e. `Qaab`) the definition is equivalent after desugaring to `(or a (or a (or b false)))`.
In other words, the definitions of `Paab` and `Qaab` are equivalent to the terms `(or a (or a b))` and `(or a a b)` respectively prior to desugaring.

More generally, for an right-associative operator `f` with nil terminator `nil`,
the term `(f t1 ... tn)` is de-sugared based on whether each `t1 ... tn` is marked with `:list`.
- The nil terminator is inserted at the tail of the function application unless `tn` is marked as `:list`,
- If `ti` is marked as `:list` where `1<=i<n`, then the term denotes the result of a concatentation operation. For example, `(f a b)` is desugared to the term `(alf.concat f a b)` when both `a` and `b` are marked as list variables. The semantics of `alf.concat` for list terms is provided later in [list-computation](#list-computation).

### Chainable

```
(declare-sort Int 0)
(declare-const and (-> Bool Bool Bool) :right-assoc)
(declare-const >= (-> Int Int Bool) :chainable)
(define-fun P ((x Int) (y Int) (z Int)) Bool (>= x y z))
(define-fun Q ((x Int) (y Int)) Bool (>= x y))
```

In the above example, `(>= x y z w)` is syntax sugar for `(and (>= x y) (>= y z))`,
whereas the term `(>= x y)` is not impacted by the annotation `:chainable` since it has fewer than 3 children.

Note that the type for chainable operators is typically `(-> T T S)` for some types `T` and `S`,
where the type of its chaining operator is `(-> S S S)`.

### Pairwise

```
(declare-sort Int 0)
(declare-const and (-> Bool Bool Bool) :right-assoc)
(declare-const distinct (-> (! Type :var T :implicit) T T Bool) :pairwise and)
(define-fun P ((x Int) (y Int) (z Int)) Bool (distinct x y z))
```
In the above example, `(distinct x y z)` is syntax sugar for `(and (distinct x y) (distinct x z) (distinct y z))`.

Note that the type for chainable operators is typically `(-> T T S)` for some types `T` and `S`,
where the type of its chaining operator is `(-> S S S)`.

## Literal types

The ALF language supports associating SMT-LIB version 3.0 syntactic categories with types. In detail, a syntax category is one of the following:
- `<numeral>` denoting the category of numerals `<digit>+`,
- `<decimal>` denoting the category of decimals `<digit>+.<digit>+`,
- `<rational>` denoting the category of rationals `<digit>+/<digit>+`,
- `<binary>` denoting the category of binary constants `#b<0|1>+`,
- `<hexadecimal>` denoting the category of hexadecimal constants `#x<hex-digit>+`,
- `<string>` denoting the category of string literals `"<char>*"`.

By default, decimal literals will be treated as syntax sugar for rational literals unless the option `--no-normalize-dec` is enabled.
Similarly, hexadecimal literals will be treated as syntax sugar for binary literals unless the option `--no-normalize-hex` is enabled.

> Note that the user does not specify that `true` and `false` are values of type `Bool`. Instead, it is assumed that the syntactic category `<boolean>` of Boolean values (`true` and `false`) has been associated with the Boolean sort. In other words, `(declare-consts <boolean> Bool)` is a part of the builtin ALF signature.

### Declaring classes of literals

The following gives an example of how to define the class of numeral constants.
```
(declare-sort Int 0)
(declare-consts <numeral> Int)
(declare-fun P ((x Int)) Bool (> x 7))
```

In the above example, the `declare-consts` command specifies that numerals (`1`, `2`, `3`, and so on) are constants of type `Int`.
The signature can now refer to arbitrary numerals in definitions, e.g. `7` in the definition of `P`.

> Internally, the command above only impacts the type rule assigned to numerals that are parsed. Furthermore, the ALF checker internally distinguishes whether a term is a numeral value, independently of its type, for the purposes of computational operators (see [computation](#computation)).

> For specifying literals whose type rule varies based on the content of the constant, the ALF language uses a distinguished variable `alf.self` which can be used in `declare-consts` definitions. For an example, see the type rule for SMT-LIB bit-vector constants, described later in [bv-literals](#bv-literals).

# <a name="computation"></a>Computational Operators in alfc

The ALF checker has builtin support for computations over all syntactic categories of SMT-LIB version 3.0.
We list the operators below, roughly categorized by domain.
However, note that the operators are polymorphic and in some cases can be applied to multiple syntactic categories.
For example, `alf.add` returns the result of adding two integers or rationals, but also can be used to add binary constants (integers modulo a given bitwidth).
Similarly, `alf.concat` returns the result of concatenating two string literals, but can also concatenate binary constants.
We remark on the semantics in the following.

In the following, we say a term is *ground* if it contains no parameters as subterms.
We say an *arithmetic value* is a numeral, decimal or rational value.
A 32-bit numeral value is a numeral value between `0` and `2^32-1`.
Binary values are considered to be in little endian form.

Core operators:
- `(alf.is_eq t1 t2)`
    - Returns `true` if `t1` is (syntactically) equal to `t2`, or `false` if `t1` and `t2` are distinct and ground. Otherwise, it does not evaluate.
- `(alf.ite t1 t2 t3)`
    - Returns `t2` if `t1` evaluates to `true`, `t3` if `t2` evaluates to `false`, and is not evaluated otherwise. Note that the branches of this term are only evaluated if they are the return term.
- `(alf.requires t1 t2 t3)`
    - Returns `t3` if `t1` is (syntactically) equal to `t2`, and is not evaluated otherwise.
- `(alf.hash t1)`
    - If `t1` is a ground term, this returns a numeral that is unique to `t1`.
Boolean operators:
- `(alf.and t1 t2)`
    - Boolean conjunction if `t1` and `t2` are Boolean values (`true` or `false`).
    - Bitwise conjunction if `t1` and `t2` are binary values.
- `(alf.or t1 t2)`
    - Boolean disjunction if `t1` and `t2` are Boolean values.
    - Bitwise disjunction if `t1` and `t2` are binary values.
- `(alf.xor t1 t2)`
    - Boolean xor if `t1` and `t2` are Boolean values.
    - Bitwise xor if `t1` and `t2` are binary values.
- `(alf.not t1)`
    - Boolean negation if `t1` is a Boolean value.
    - Bitwise negation if `t1` is a binary values.
Arithmetic operators:
- `(alf.add t1 t2)`
    - If `t1` and `t2` are arithmetic values, then this returns the multiplication of `t1` and `t2`, which is a rational value if either of `t1, t2` is a rational value, or a numeral value otherwise.
    - If `t1` and `t2` are binary values of the same bitwidth, this returns the binary value corresponding to their (unsigned) addition modulo their bitwidth.
- `(alf.mul t1 t2)`
    - If `t1` and `t2` are arithmetic values, then this returns the multiplication of `t1` and `t2`, which is a rational value if either of `t1, t2` is a rational value, or a numeral value otherwise.
    - If `t1` and `t2` are binary values of the same bitwidth, this returns the binary value corresponding to their (unsigned) multiplication modulo their bitwidth.
- `(alf.neg t1)`
    - If `t1` is a arithmetic value, this returns the arithmetic negation of `t1`.
    - If `t1` is a binary value, this returns its (signed) arithmetic negation.
- `(alf.qdiv t1 t2)`
    - If `t1` and `t2` are arithmetic values and `t2` is non-zero, then this returns the rational division of `t1` and `t2`.
- `(alf.zdiv t1 t2)`
    - If `t1` and `t2` are numeral values and `t2` is non-zero, then this returns the integer division (floor) of `t1` and `t2`.
- `(alf.is_neg t1)`
    - If `t1` is an arithmetic value, this returns `true` if `t1` is zero and `false` otherwise. Otherwise, this operator is not evaluated.
- `(alf.is_zero t1)`
    - If `t1` is an arithmetic value, this returns `true` if `t1` is zero and `false` otherwise. Otherwise, this operator is not evaluated.
String operators:
- `(alf.len t1)`
    - Binary length (bitwidth) if `t1` is a binary value.
    - String length if `t1` is a string value.
- `(alf.concat t1 t2)`
    - The concatenation of bits if `t1` and `t2` are binary values.
    - The concatenation of strings if `t1` and `t2` are string values.
- `(alf.extract t1 t2 t3)`
    - If `t1` is a binary value and `t2` and `t3` are numeral values, this returns the binary value corresponding to the bits in `t1` from position `t2` through `t3` if `0<=t2`, or the empty binary value otherwise.
    - If `t1` is a string value and `t2` and `t3` are numeral values, this returns the string value corresponding to the characters in `t1` from position `t2` through `t3` inclusive if `0<=t2`, or the empty string value otherwise.
- `(alf.find t1 t2)`
    - If `t1` and `t2` are string values, this returns a numeral value corresponding to the first index (left to right) where `t2` occurs as a substring of `t1`, or the numeral value `-1` otherwise.
Conversion operators:
- `(alf.to_z t1)`
    - If `t1` is a numeral value, return `t1`.
    - If `t1` is a rational value, return the numeral value corresponding to the floor of `t1`.
    - If `t1` is a binary value, this returns the numeral value corresponding to `t1`.
    - If `t1` is a string value containing only digits, this returns the numeral value. This operation is agnostic to leading zeroes.
- `(alf.to_q t1)`
    - If `t1` is a rational value, return `t1`.
    - If `t1` is a numeral value, this returns the (integral) rational value that is equivalent to `t1`.
- `(alf.to_bin t1 t2)`
    - If `t1` is a binary value and `t2` is a 32-bit numeral value, this returns a binary value whose value is `t1` and whose bitwidth is `t2`.
    - If `t1` and `t2` are numeral values, return the binary value whose value is `t1` (modulo `2^t2`) and whose bitwidth is `t2`.
- `(alf.to_str t1)`
    - If `t1` is a string value, return `t1`.
    - Otherwise, if `t1` is a binary or arithmetic value, return the string value corresponding to the result of printing `t1`.

The ALF checker eagerly evaluates ground applications of computational operators.
In other words, the term `(alf.add 1 1)` is syntactically equivalent in all contexts to `2`.

Currently, apart from applications of `alf.ite`, all terms are evaluated bottom-up.
This means that e.g. in the evaluation of `(alf.or A B)`, both `A` and `B` are always evaluated even if `A` evaluates to `true`.

### Computation Examples

```
(alf.and true false)        == false
(alf.and #b1110 #b0110)     == #b0110
(alf.or true false)         == true
(alf.xor true true)         == false
(alf.xor #b111 #b011)       == #b100
(alf.not true)              == false
(alf.not #b1010)            == #b0101
(alf.add 1 1)               == 2
(alf.add 1/2 1/3)           == 5/6
(alf.add #b01 #b01)         == #b10
(alf.mul 1/2 1/4)           == 1/8
(alf.neg -15)               == 15
(alf.qdiv 7 2)              == 7/2
(alf.qdiv 7 0)              == (alf.qdiv 7 0)
(alf.zdiv 12 3)             == 4
(alf.zdiv 7 2)              == 3
(alf.is_neg 0)              == false
(alf.is_neg -7/2)           == true
(alf.is_zero 1/100)         == false
(alf.len "abc")             == 3
(alf.len #b11100)           == 5
(alf.concat "abc" "def")    == "abcdef"
(alf.concat #b000 #b11)     == #b00011
(alf.extract "abcdef" 0 1)  == "ab"
(alf.extract "abcdef" -1 3) == ""
(alf.extract "abcdef" 1 10) == "bcdef"
(alf.extract #b11100 2 5)   == #b111
(alf.extract #b11100 2 1)   == #b
(alf.extract #b111000 1 10) == #b11100
(alf.extract #b10 -1 2)     == #b
(alf.find "abc" "bc")       == 1
(alf.find "abc" "")         == 0
(alf.find "abcdef" "g")     == -1
(alf.to_z 3/2)              == 1
(alf.to_z 45)               == 45
(alf.to_z "451")            == 451
(alf.to_z "0051")           == 51
(alf.to_z "5a1")            == (alf.to_z "5a1")
(alf.to_q 6)                == 6/1
(alf.to_bin 3 4)            == #b0011
(alf.to_bin #b1 4)          == #b0001
(alf.to_bin #b10101010 2)   == #b10
(alf.to_str 123)            == "123"
(alf.to_str 1/2)            == "1/2"
(alf.to_str #b101)          == "#b101"
```

Note the following examples of core operators for the given signature

```
(declare-sort Int 0)
(declare-const x Int)
(declare-const y Int)
(declare-const a Bool)
;;
(alf.is_eq 0 1)                         == false
(alf.is_eq x y)                         == false
(alf.is_eq x x)                         == true
(alf.requires x 0 true)                 == (alf.requires x 0 true)
(alf.requires x x y)                    == y
(alf.requires x x Int)                  == Int
(alf.ite false x y)                     == y
(alf.ite true Bool Int)                 == Bool
(alf.ite a x x)                         == (alf.ite a x x)

(alf.is_eq 2 (alf.add 1 1))             == true
(alf.is_eq x (alf.requires x 0 x))      == false
(alf.ite (alf.is_eq x 1) x y)           == y
(alf.ite (alf.requires x 0 true) x y)   == (alf.ite (alf.requires x 0 true) x y)
```

In the above, it is important to note that `alf.is_eq` is a check for syntactic equality after evaluation.
It does not require that its arguments denote values, so for example `(alf.is_eq x y)` returns `false`.

## <a name="list-computation"></a> List computations

Below, we assume that `f` is right associative operator with nil terminator `nil` and `t1, t2` are ground. Otherwise, the following operators do not evaluate.
We describe the evaluation for right associative operators; left associative evaluation is defined analogously.
We say that a term is an `f`-list with children `t1 ... tn` if it is of the form `(f t1 ... tn)` where `n>0` or `nil` if `n=0`.

List operators:
- `(alf.cons f t1 t2)`
    - If `t2` is an `f`-list, then this returns the term `(f t1 t2)`.
- `(alf.concat f t1 t2)`
    - If `t1` is an `f`-list with children `t11 ... t1n` and `t2` is an `f`-list with children `t21 ... t2m`, this returns `(f t11 ... t1n t21 ... t2m)` if `n+m>0` and `nil` otherwise. Otherwise, this operator does not evaluate.
- `(alf.extract f t1 t2)`
    - If `f` is a right associative operator with nil terminator with nil terminator `nil`, `t1` is `(f s0 ... s{n-1})`, and `t2` is a numeral value such that `0<=t2<n`, then this returns `s_{t2}`. Otherwise, this operator does not evaluate.
- `(alf.find f t1 t2)`
    - If `f` is a right associative operator with nil terminator with nil terminator `nil` and `t1` is `(f s0 ... s{n-1})`, then this returns the smallest numeral value `i` such that `t2` is syntactically eqaul to `si`, or `-1` if no such `si` can be found. Otherwise, this operator does not evaluate.

### List Computation Examples

The terms on both sides of the given evaluation are written in their form prior to desugaring, where recall that e.g. `(or a)` after desugaring is `(or a false)` and `(or a b)` is `(or a (or b false))`.

```
(declare-const or (-> Bool Bool Bool) :right-assoc-nil false)
(declare-const and (-> Bool Bool Bool) :right-assoc-nil true)
(declare-const a Bool)
(declare-const b Bool)

(alf.cons or a (or a b))            == (or a a b)
(alf.cons or false (or a b))        == (or false a b)
(alf.cons or (or a b) (or b))       == (or (or a b) b)
(alf.cons or false false)           == false
(alf.cons or a b)                   == (alf.cons or a b)
(alf.cons or a (or b))              == (or a b)
(alf.cons and (or a b) (and b))     == (and (or a b) b)
(alf.cons and true (and a))         == (and a)
(alf.cons and (and a) true)         == (and (and a))

(alf.concat or (or a b) (or b))     == (or a b b)
(alf.concat or false (or b))        == (or b)
(alf.concat or (or a b b) false)    == (or a b b)
(alf.concat or a (or b))            == (alf.concat or a (or b))
(alf.concat or (or a) b)            == (alf.concat or (or a) b)
(alf.concat or (or a) (or b))       == (or a b)
(alf.concat or (and a b) false)     == (alf.concat or (and a b) false)

(alf.extract or (or a b a) 1)       == b
(alf.extract or (or a) 0)           == a
(alf.extract or false 0)            == (alf.extract or false 0)
(alf.extract or (or a b a) 3)       == (alf.extract or (or a b a) 3)
(alf.extract or (and a b b) 0)      == (alf.extract or (and a b b) 0)

(alf.find or (or a b a) b)          == 1
(alf.find or (or a b a) true)       == -1
(alf.find or (and a b b) a)         == (alf.find or (and a b b) a)

```


## Type rule for BitVector concatentation

```
(declare-sort Int 0)
(declare-consts <numeral> Int)
(declare-type BitVec (Int))

(declare-const concat (->
  (! Int :var n :implicit)
  (! Int :var m :implicit)
  (BitVec n)
  (BitVec m)
  (BitVec (alf.add n m))))

(declare-fun x () (BitVec 2))
(declare-fun y () (BitVec 3))
(define-fun z () (BitVec 5) (concat x y))
```

Above, we define a type declaration for `BitVec` that expects an integer (i.e. denoting the bitwidth) as an argument.
Then, a type rule is given for bitvector concatenation `concat`, involves the result of invoking `alf.add` on the bitwidth of its two arguments.

Since `alf.add` only evaluates on numeral values, this means that this type rule will only give the intended result when the bitwidth arguments to this function are concrete.
If on the other hand we defined:
```
...
(declare-const a Int)
(declare-const b Int)
(declare-fun x2 () (BitVec a))
(declare-fun y2 () (BitVec b))
```
The type of `(concat x2 y2)` is the above example would be `(BitVec (alf.add a b))`.
Further use of this term would lead to type checking errors, in particular since the ALF checker does not support matching on computational operators.

## Type rule for BitVector constants

```
(declare-sort Int 0)
(declare-consts <numeral> Int)
(declare-type BitVec (Int))

(declare-consts <binary> (BitVec (alf.len alf.self)))

(define-const x (BitVec 3) #b000)
```
To define the class of binary values, whose type depends on the number of bits they contain, the ALF checker provides support for a distinguished parameter `alf.self`.
The type checker for values applies the substitution mapping `alf.self` to the term being type checked.
This means that when type checking the binary constant `#b0000`, its type prior to evaluation is `(BitVec (alf.len #b0000))`, which evaluates to `(BitVec 4)`.

# Declaring Proof Rules

The ALF language supports a command `declare-rule` for defining proof rules. Its syntax is given by:
```
(declare-rule <symbol> (<typed-param>*) <assumption>? <premises>? <arguments>? <requirements>? :conclusion <term>)
where
<assumption>    ::= :assumption <term>
<premises>      ::= :premises (<term>*) | :premise-list <term> <term>
<arguments>     ::= :args (<term>*)
<requirements>  ::= :requires ((<term> <term>)*)
```

A proof rule begins by defining a list of free parameters, followed by 4 optional fields and a conclusion term.
These fields include:
- `<premises>`, denoting the premise patterns of the proof rule. This is either a list of formulas (via `:premises`) or the specification of list of premises via (via `:premise-list`), which will be described in detail later.
- `<arguments>`, denoting argument patterns of provide to a proof rule.
- `<requirements>`, denoting a list of pairs of terms.
Proof rules with assumptions `<assumption>` are used in proof with local scopes and will be discussed in detail later.

At a high level, an application of a proof rule is given a concrete list of (premise) proofs, and a concrete list of (argument) terms.
A proof rule checks if a substitution `S` can be found such that:
- The formulas proven by the premise proofs match provided premise patterns under substitution `S`,
- The argument terms match the provided argument patterns under substitution `S`,
- The requirements are *satisfied* under substitution `S`, namely, each pair of terms in the requirements list evaluates pairwise to the same term.
If these criteria are met, then the proof rule proves the result of applying `S` to the conclusion term.

A proof rule is only well defined if the free parameters of the requirements and conclusion term are also contained in the arguments and premises.

> Internally, proofs can be seen as terms whose type is given by a distinguished `Proof` type. In particular, `Proof` is a type whose kind is `(-> Bool Type)`, where the argument of this type is the formula that is proven. For example, `(Proof (> x 0))` is the proof that `x` is greater than zero. By design, the user cannot declare terms involving type `Proof`. Instead, proofs can only be constructed via the commands `assume` and `step` as we describe in [proofs](#proofs).


### Example rule: Reflexivity of equality

```
(declare-const = (-> (! Type :var T :implicit) T T Bool))
(declare-rule refl ((T Type) (t T))
    :premises ()
    :args (t)
    :conclusion (= t t)
)
```

The above example defines the rule for reflexivity of equality.
First a parameter list is provided that introduces a type `T` and a term `t` of that type.
The rule takes no premises, a term `t` and proves `(= t t)`.
Notice that the type `T` is a part of the parameter list and not explicitly provided as an argument to this rule.

### Example rule: Symmetry of Equality

```
(declare-const = (-> (! Type :var T :implicit) T T Bool))
(declare-rule symm ((T Type) (t T) (s T))
    :premises ((= t s))
    :conclusion (= s t)
)
```

This rule specifies symmetry of equality. This rule takes as premise an equality `(= t s)` and no arguments.
In detail, an application of this proof rule for premise proof `(= a b)` for concrete terms `a,b` will compute the substitution `{ t -> a, s -> b }` and apply it to the conclusion term to obtain `(= b a)`.

## Requirements

A list of requirements can be given to a proof rule.

```
(declare-sort Int 0)
(declare-consts <numeral> Int)
(declare-fun >= (Int Int) Bool)
(declare-rule leq-contra ((x Int))
    :premise ((>= x 0))
    :requires (((alf.is_neg x) true))
    :conclusion false)
```

This rule expects an arithmetic inequality.
It requires that the left hand side of this inequality `x` is a negative numeral, which is checked via the requirement `:requires (((alf.is_neg x) true))`.

## Premise lists

A rule can take an arbitrary number of premises via the syntax `:premise-list <term> <term>`. For example:

```
(declare-fun and (-> Bool Bool Bool) :right-assoc-nil true)
(declare-rule and-intro ((F Bool))
    :premise-list F and
    :conclusion F)
```
This syntax specifies that the number of premises that are provided to this rule are arbitrary.
When applying this rule, the formulas proven to this rule (say `F1 ... Fn`) will be collected and constructed as a single formula via the provided operator (`and`), and subsequently matched against the premise pattern `F.
In particular, in this case `F` is bound to `(and F1 ... Fn)`.
The conclusion of the rule returns `F` itself.

Note that the type of functions provided as the second argument of `:premise-list` should be operators that are marked to take an arbitrary number of arguments, that is those marked with `:right-assoc-nil`, `:chainable`.

## Axioms

The ALF language supports a command `declare-axiom`, which is a simplified version of `declare-rule`:
```
(declare-axiom <symbol> (<typed-param>*) <requirements>? <term>)
<requirements>  ::= :requires ((<term> <term>)*)
```

The command
```
(declare-axiom S ((t1 T1) .. (tn Tn)) R? t)
```
is syntax sugar for
```
(declare-rule S ((t1 T1) ... (tn Tn)) :args (t1 ... tn) R? :conclusion t)
```
where `R` is an (optional) requirements annotation.
More generally, any argument `t1 ... tn` that is marked with `:implicit` from the argument list of the declared rule.

### Example: reflexive equality as axiom

Note the following definition is equivalent to the previously declared version of `refl`:
```
(declare-const = (-> (! Type :var T :implicit) T T Bool))
(declare-axiom refl ((T Type :implicit) (t T))
    (= t t)
)
```
The argument `T` to `refl` has been marked as `:implicit`, and thus it does not appear in the
argument.


#  <a name="proofs"></a> Writing Proofs

The ALF language provies the commands `assume` and `step` for defining proofs. Their syntax is given by:
```
(assume <symbol> <term>)
(step <symbol> <term>? :rule <symbol> <premises>? <arguments>?)
where
<premises>      ::= :premises (<term>*)
<arguments>     ::= :args (<term>*)
```
### Example proof: symmetry of equality

```
(declare-const = (-> (! Type :var T :implicit) T T Bool))
(declare-rule symm ((T Type) (t T) (s T))
    :premises ((= t s))
    :conclusion (= s t)
)
(declare-sort Int 0)
(declare-const a Int)
(declare-const b Int)
(assume @p0 (= a b))
(step @p1 (= b a) :rule symm :premises (@p0))
```

## Proofs with local assumptions

The ALF language includes commands `assume-push` and `step-pop` with the same syntax as `assume` and `step` respectively.
However, the former can be seen as introducing a local assumption that is consumed by the latter.
We give an example of this in following.

```
(declare-const => (-> Bool Bool Bool))
(declare-rule implies-intro ((F Bool) (G Bool))
  :assumption F
  :premises (G)
  :conclusion (=> F G)
)
(declare-rule contra ((F Bool))
  :premises (false)
  :args (F)
  :conclusion F)
(assume-push @p1 false)
(step @p2 true :rule contra :premises (@p1) :args (true))
(step-pop @p3 (=> false true) :rule implies-intro :premises (@p2))
```

In this signature, we define a proof rule for implication introduction.
The rule takes an assumption `:assumption F`, which denotes that it will consume a local assumption introduced by `assume-push`.
We also define a rule for contradiction that states any formula can be proven if we prove `false`.

The command `assume-push` denotes that `@p1` is a (locally assumed) proof of `false`.
The proof `@p1` is then used as a premise to the step `@p2`, which proves `true`.
The command `step-pop` then consumes the proof of `@p1` and binds `@p3` to a proof of `(=> false true)`.
Notice that `@p1` is removed from scope after `@p3` is applied.

Locally assumptions can be arbitrarily nested, for example the above can be extended to:
```
...
(assume-push @p0 true)
(assume-push @p1 false)
(step @p2 true :rule contra :premises (@p1) :args (true))
(step-pop @p3 (=> false true) :rule implies-intro :premises (@p2))
(step-pop @p4 (=> true (=> false true)) :rule implies-intro :premises (@p3))
```

# Side Conditions

The ALF language supports a command for defining ordered lists of rewrite rules that can be seen as computational side conditions.
The syntax for this command is as follows.
```
(program <symbol> (<typed-param>*) (<type>*) <type> ((<term> <term>)+))
```
This command declares a program named `<symbol>`.
The provided type parameters are implicit and are used to define its type signature and body.

The type of the program is given immediately after the parameter list, provided as a list of argument types and a return type.
The semantics of the program is given by a non-empty list of pairs of terms, which we call its *body*.
For program `f`, This list is expected to be a list of terms of the form `(((f t11 ... t1n) r1) ... ((f tm1 ... tmn) rm))`
where `t11...t1n, ..., tm1...tmn` do not contain computational operators.
A (ground) term `(f s1 ... sn)` evaluates by finding the first term in the first position of a pair of this list that matches it for substitution `S`, and returns the result of applying `S` to the right hand side of that pair.

> Terms in program bodies are not statically type checked. Evaluating a program may introduce non-well-typed terms if the program body is malformed.

> For each case `((f ti1 ... tin) ri)` in the program body, the free parameters in `ri` are expected to be a subset of the free parameters in `(f ti1 ... tin)`. Otherwise, an error is thrown.

> If a case is provided `(si ri)` in the definition of program `f` where `si` is not an application of `f`, an error is thrown.

### Example: Contains in a `or` term

The following program (recursively) computes whether a formula `l` is contained as the direct child of an application of `or`:
```
(declare-const or (-> Bool Bool Bool) :right-assoc-nil false)
(program contains
    ((l Bool) (x Bool) (xs Bool :list))
    (Bool Bool) Bool
    (
        ((contains l false)     false)
        ((contains l (or l xs)) true)
        ((contains l (or x xs)) (contains l xs))
    )
)
```

First, we declare the parameters `l, x, xs`, each of type `Bool`.
These parameters are used for defining the body of the program, but do *not* necessarily coincide with the expected arguments to the program.
We then declare the type of the program `(Bool Bool) Bool`, i.e. the type of `contains` is a function expecting two Booleans and returning a Boolean.
The body of the program is then given in three cases.
First, terms of the form `(contains l false)` reduce to `false`, that is, we failed to find `l` in the second argument.
Second, terms of the form `(contains l (or l xs))` reduce to `true`, that is we found `l` in the first position of the second argument.
Otherwise, terms of the form `(contains l (or x xs))` reduce to `(contains l xs)`, in other words, we make a recursive call to find `l` in the tail of the list `xs`.

### Example: Substitution

```
(program substitute
  ((T Type) (U Type) (S Type) (x S) (y S) (f (-> T U)) (a T) (z U))
  (S S U) U
  (
  ((substitute x y x)     y)
  ((substitute x y (f a)) (_ (substitute x y f) (substitute x y a)))
  ((substitute x y z)     z)
  )
)
```

The term `(substitute x y t)` replaces all occurrences of `x` by `y` in `t`.
Note that this side condition is fully general and does not depend on the shape of terms in `t`.
In detail, the ALF checker treats all function applications as curried.
In particular, this implies that `(f a)` matches any application term since both `f` and `a` are parameters.
Thus, the side condition is written in three cases: either `t` is `x` in which case we return `y`,
`t` is a function application in which case we recurse, or otherwise `t` is a constant not equal to `x` and we return itself.

### Example: Term evaluator

```
(declare-sort Int 0)
(declare-consts <numeral> Int)
(declare-const = (-> (! Type :var T :implicit) T T Bool))
(declare-const + (-> Int Int Int))
(declare-const - (-> Int Int Int))
(declare-const < (-> Int Int Bool))
(declare-const <= (-> Int Int Bool))

(program run_evaluate ((T Type) (U Type) (S Type) (a T) (b U) (z S))
    (S) S
    (
      ((run_evaluate (= a b))  (alf.is_eq (run_evaluate a) (run_evaluate b)))
      ((run_evaluate (< a b))  (alf.is_neg (run_evaluate (- a b))))
      ((run_evaluate (<= a b)) (let ((x (run_evaluate (- a b))))
                                 (alf.or (alf.is_neg x) (alf.is_zero x))))
      ((run_evaluate (+ a b))  (alf.add (run_evaluate a) (run_evaluate b)))
      ((run_evaluate (- a b))  (alf.add (run_evaluate a) (alf.neg (run_evaluate b))))
      ((run_evaluate z)        z)
    )
)
```

### Example: A computational type rule

```
(declare-sort Int 0)
(declare-sort Real 0)
(program arith.typeunion ()
    (Type Type) Type
    (
      ((arith.typeunion Int Int) Int)
      ((arith.typeunion Int Real) Real)
      ((arith.typeunion Real Int) Real)
      ((arith.typeunion Real Real) Real)
    )
)
(declare-const + (-> (! Type :var T :implicit)
                     (! Type :var U :implicit)
                     T U (arith.typeunion T U)))
```

In the above example, a side condition is being used to define the type rule for the function `+`.
In particular, `arith.typeunion` is a program taking two types and returning a type, which is `Real` if either argument is `Real` or `Int` otherwise.
The return type of `+` invokes this side condition, which conceptually is implementing a policy for subtyping over arithmetic types which the ALF checker does not have builtin support for.


## Match statements in ALF

The ALF checker supports an operator `alf.match` for performing pattern matching on a target term. The syntax of this term is:
```
(alf.match (<typed-param>*) <term> ((<term> <term>)*))
```
The term `(alf.match (...) t ((s1 r1) ... (sn rn)))` finds the first term `si` in the list `s1 ... sn` that `t` can be matched with under some substitution and returns the result of applying that substitution to `ri`.

> Similar to programs, the free parameters of `ri` must be a subset of `si`, or else an error is thrown.

### Example:

### Example: Transitivity proof rule with a premise list

```
(declare-sort Int 0)
(declare-const = (-> (! Type :var T :implicit) T T Bool))
(declare-const and (-> Bool Bool Bool) :left-assoc)

(program mk_trans ((t1 Int) (t2 Int) (t3 Int) (t4 Int) (tail Bool :list))
    (Int Int Bool) Bool
    (
        ((mk_trans t1 t2 (and (= t3 t4) tail)) (alf.requires t2 t3 (mk_trans t1 t4 tail)))
        ((mk_trans t1 t2 true)                 (= t1 t2))
    )
)

(declare-rule trans (E Bool))
    :premise-list E and
    :conclusion
        (alf.match ((t1 Int) (t2 Int) (tail Bool :list))
        E
        ((and (= t1 t2) tail) (mk_trans t1 t2 tail)))
)
```

For simplicity, the rule is given only for equalities of the integer sort, although this rule can be generalized.

# Including and referencing files

The ALF checker supports the following commands for file inclusion:
- `(include <string>)`, which includes the file indicated by the given string. The path to the file is taken relative to the directory of the file that includes it.
- `(reference <string>)`, which similar to `include` includes the file indicated by the given string, and furthermore marks that file as being the *reference input* for the current run of the checker (see below).

## Validation Proofs via Reference Inputs

When the ALF checker encounters a command of the form `(reference <string>)`, the checker enables a further set of checks that ensures that all assumptions in proofs correspond to assertions from the reference file.

In particular, when the command `(reference "file.smt2")` is read, the ALF checker will parse `file.smt2`.
The definitions and declaration commands in this file will be treated as normal, that is, they will populate the symbol table of the ALF checker as they normally would if they were to appear in an `*.smt3` input.
The commands of the form `(assert F)` will add `F` to a set of formulas we will refer to as the *reference assertions*.
Other commands in `file.smt2` (e.g. `set-logic`, `set-option`, and so on) will be ignored.

If alfc has read a reference file, then for each command of the form `(assume <symbol> G)`, alfc will check whether `G` occurs in the set of parsed reference assertions.
If it does not, then an error is thrown indicating that the proof is assuming a formula that is not a part of the original input.

> Only one reference command can be executed for each run of alfc.

> Incremental `*.smt2` inputs are not supported as reference files in the current version of alfc.

## Partial Validation

Since the validation is relying on the fact that alfc can faithfully parse the original *.smt2 file, validation will only succeed if the signatures used by the ALF checker exactly match the syntax for terms in the *.smt2 file.
Minor changes in how terms are represented will lead to mismatches.
For this reason, alfc additionally supports providing an optional normalization routine to the `reference` command:
- `(reference <string> <term>)`, which includes the file indicated by the given string and specifies all assumptions must match an assertion after running the provided normalization function.

For example:
```
(declare-sort Int 0)
(declare-sort Real 0)
(declare-const / (-> Int Int Real))
(program normalize ((T Type) (S Type) (f (-> S T)) (x S) (a Int) (b Int))
   (T) T
   (
     ((normalize (/ a b)) (alf.qdiv a b))
     ((normalize (f x))   (_ (normalize f) (normalize x)))
     ((normalize y)       y)
   )
)
(reference "file.smt2" normalize)
```
Here, `normalize` is introduced as a program which recursively replaces all occurrences of division (over integer constants) with the resulting rational constant.
This method can be used for handling solvers that interpret constant division as the construction of a rational constant.

# Oracles


## Example: Invoking the DRAT proof checker drat-trim.

# Compiling signatures to C++

# Appendix

## Command line options

The ALF command line interface can be invoked by `alfc <option>* <file>` where `<option>` is one of the following:
- `--help`: displays a help message.
- `--show-config`: displays the build information for the given binary.
- `--no-print-let`: do not letify the output of terms in error messages and trace messages.
- `--gen-compile`: output the C++ code for all included signatures from the input file.
- `--run-compile`: use the compiled C++ signatures whenever available.
- `--no-rule-sym-table`: do not use a separate symbol table for proof rules and declared terms.
- `--no-normalize-dec`: do not treat decimal literals as syntax sugar for rational literals.
- `--no-normalize-hex`: do not treat hexadecimal literals as syntax sugar for binary literals.
- `-t <tag>`: enables the given trace tag (for debugging).
- `-v`: verbose mode, enable all standard trace messages.

## Full syntax for commands



## Proofs as terms

This section overviews the semantics of proofs in the ALF language.
Proof checking can be seen as a special instance of type checking terms involving the `Proof` and `Quote` types.
The type system of the ALF can be summarized as follows, where `t : S` are assumed axioms for all atomic terms `t` of type `S`:

```
f : (-> (Quote u) S)  t : T
---------------------------- if u * sigma = t
(f t) : S * sigma


f : (-> U S)  t : T
------------------- if U * sigma = T
(f t) : S * sigma

for all other (non-Quote) types U.

```

### Declared rules

The command:
```
(declare-rule s ((v1 T1) ... (vi Ti)) :premises (p1 ... pn) :args (t1 ... tm) :requires ((r1 s1) ... (rk sk)) :conclusion t)
```
can be seen as syntax sugar for:
```
(declare-fun s
    (->
        (! T1 :var v1 :implicit) ... (! Ti :var vi :implicit)
        (Proof p1) ... (Proof pn)
        (Quote t1) ... (Quote tm)
        (alf.requires r1 s1 ... (alf.requires rk sk
            (Proof t)))))
```

### Proof assumptions

The command:
```
(assume s f)
```
can be seen as syntax sugar for:
```
(declare-const s (Proof f))
```

### Proof steps

The command:
```
(step s f :rule r :premises (p1 ... pn) :args (t1 ... tm))
```
can be seen as syntax sugar for:
```
(define-fun s () (Proof f) (r p1 ... pn t1 ... tm))
```
Notice this is only the case if `r` does not take an assumption or premise list as arguments, that is, the declaration of `r` does not involve `:assumption` or `:premise-list`.