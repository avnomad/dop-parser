# Disambiguating Operator Precedence Parser

An operator precedence parser variation that adds a disambiguation step in order
to support overloaded fixities, juxtaposition and other features.

[![GitHub Tag](https://img.shields.io/github/tag/avnomad/dop-parser.svg?maxAge=86400)](#)
[![Build Status](https://travis-ci.org/avnomad/dop-parser.svg?branch=default)](https://travis-ci.org/avnomad/dop-parser)
[![Coverage Status](https://coveralls.io/repos/github/avnomad/dop-parser/badge.svg)](https://coveralls.io/github/avnomad/dop-parser)

## Introduction

The goal of this project was to create an efficient and versatile parser for use
in implementing an extensible language.

There are dozens of parsing techniques and variations thereof, making the room
for a new one difficult to see. The following is an oversimplification, but
popular parsers like LL(k) and LR(k) can't handle the non-determinism caused by
the coexistence of certain operator fixities, while general parsers like GLR
and Earley can't guarantee linear time complexity. None of the above makes it
easy or efficient to add and remove operators on the fly.

The variation of the operator precedence parser that uses a one-dimensional
operator table, is ideal for changing the operators on the fly, but the vanilla
version can't handle all the constructs seen in contemporary programming
languages.

The idea was to start with a variation of an operator precedence parser similar
to [this][6] and add a sort of pre-processing step doing an arbitrary look-ahead
to achieve better disambiguation, support for juxtaposition and other desirable
properties. This disambiguation step had to guarantee every token is processed
at most twice to maintain the linearity of the operator precedence parser.

## Key features

- Linear time and memory consumption with regard to the number of input tokens
  in the worst case.
- Works with certain ambiguous grammars, parsing unambiguous strings and
  reporting ambiguous ones.
- Supports infix, prefix and postfix operators as well as overloading an
  operator's fixity to be any combination of those.
- Supports confix operators and list-like structures (lists, tuples, sets, etc.)
- Supports juxtaposition.
- Returns an abstract syntax tree (not a concrete one).
- Adding/removing operators is done by just adding/removing them to/from a map.

## Limitations

These are limitations of the implementation, rather than of the algorithm but:
- There is no scanner so tokens have to be separated by whitespace.
- The priority and associativity of the prefix and postfix operators is not
  implemented yet and ignored. Surprisingly enough, this *complicates* code.
- General distfix operators haven't been implemented yet.
- The parser stops at the first error and there is no support for
  [expressive diagnostics][7].

## How it works

I have yet to find a book, post or paper describing this disambiguation scheme
(it is possible that I invented it), so this should serve as an overview:

### Definitions

1. *operand*: Any single token that has not been declared as an *operator*. It
			  is intended to represent literals like `b` or `42`.
2. *operator*: Any single token that has been declared as such a *prefix*,
			   *infix*, or *postfix* operator. The declaration assigns certain
			   attributes to the operator like its priority and associativity.
3. *initiator*: Any single token that has been declared to begin a *confix* or
				*list-like* *expression*. The intention is for `(`, `[`, `{`,
				etc. to be used as *initiators*.
4. *terminator*: Any single token that has been declared to end a *confix* or
				 *list-like* *expression*. The intention is for `)`, `]`, `}`,
				 etc. to be used as *terminators*.
5. *separator*: Any single token that has been declared to separate individual
				sub-expressions of a *list-like* structure. The intention is for
				`,` to be used as a *separator*.
6. *operable*: Any token or group of tokens forming a well-formed *expression*
			   that evaluates to value and can have an *operator* applied to it.
			   The difference from *expression* is that future versions of the
			   parser will support expressions evaluating to operators.
7. *expression*: Any token or group of tokens that follows the usual rules for
				 building expressions from operators and operands. (e.g. E ⟶ E
				 infix_op E)

### Disambiguation


## Prerequisites

In order to build the project you need to have a recent version of a
[D compiler][1] and [dub package and build manager][2] installed.

## Build

Execute `dub build` to build the project, or `dub test` to build and run unit
tests.

## Usage

The project includes a command-line interactive driver that invokes the parser.

You can build and run the project with a single command: `dub run`. Or you can
Invoke it with `./build/dop-parser` after building it.

You will first be given instructions on how to define operators and then the
option to submit expressions for parsing. The parser responds to each submitted
expression with either a Lisp-list-like representation of the syntax tree, or
a syntax error.

Note that there is no scanner, so tokens are separated by whitespace.

## Compatibility

* You should be able to build the parser using any one of dmd, gdc and ldc.
* You should also be able to run it on any one of Windows, Linux and Mac OS X,
  although only the first two have been tested.

## Mirrors

Currently the project exists in two different mirrors that are kept in sync:
1. <https://github.com/avnomad/dop-parser>
2. <https://bitbucket.org/avnomad/dop-parser>

The 2nd presents a slightly more accurate picture of the project. That's because
I've developed it using Mercurial and I've used a few features that aren't
available in Git. Although all the information is preserved by the hg-git
bridge, some commit meta-data will only be visible as part of the commit message
in GitHub.

## Future direction

The first step would be to add negative tests to complete the test suite and
reach 100% code coverage. In our case, this translates to tests ensuring correct
behaviour on input that contains syntax errors.

Then priorities and associativities need to implemented for prefix and postfix
operators.

In the long run, more interesting features can be added, like expressions that
evaluate to operators instead of values.

## Contributing

In order to contribute, just open a pull request in either GitHub or BitBucket.

## Notes

- I've used Hg branches in a rather unusual way, in this project. [This][3] blog
  post attempts to explain how and why.
- This project uses [Semantic Versioning][4]. Since there no stable public API
  yet, the standard only prescribes that major version should be 0, not when
  minor and patch versions should increase. So I increase minor version when
  significant new functionality is added (regardless of its effect on the API)
  and patch version when bugs are fixed.

## License

This is _free_ software. You can redistribute it and/or modify it under the
terms of the [GNU General Public License][5] version 3 or later.



[1]: https://dlang.org/
[2]: http://code.dlang.org/getting_started
[3]: http://blog.cornercase.gr/post/2018/03/22/Mercurial-branches-as-categories
[4]: https://semver.org/
[5]: https://www.gnu.org/licenses/gpl.html
[6]: http://h14s.p5r.org/2014/10/shiftreduce-expression-parsing-by-douglas-gregor.html
[7]: https://clang.llvm.org/diagnostics.html
