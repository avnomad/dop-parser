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
and Earley can't guarantee linear time complexity. None of the aforementioned
parsers makes it easy or efficient to add and remove operators on the fly.

The variation of the operator precedence parser that uses a one-dimensional
operator table, is ideal for changing the operators on the fly, but the vanilla
version can't handle all the constructs commonly used in contemporary
programming languages.

The idea was to start with a variation of an operator precedence parser similar
to [this][6] and add a sort of pre-processing step doing an arbitrary look-ahead
to achieve better disambiguation, support for juxtaposition and other desirable
properties. This disambiguation step had to guarantee every token is processed
at most twice to maintain the linearity of the operator precedence parser.

## Key features

- Linear time and memory consumption with regard to the number of input tokens
  in the worst case.
- Works with a class of ambiguous grammars, parsing unambiguous strings and
  reporting ambiguous ones.
- Supports infix, prefix and postfix operators as well as overloading an
  operator's fixity to be any combination of those.
- Supports confix operators and list-like structures (lists, tuples, sets, etc.)
- Supports juxtaposition.
- Returns an abstract syntax tree (not a concrete one).
- Adding/removing operators is done by just adding/removing them to/from a map.

## Limitations

Most of these are limitations of the implementation, not the algorithm but:

- There is no scanner, so tokens have to be separated by whitespace.
- The priority and associativity of the prefix and postfix operators is not
  implemented yet and ignored. Surprisingly enough, this *complicates* code.
- General distfix operators haven't been implemented yet.
- The parser stops at the first error and there is no support for
  [expressive diagnostics][7].
- There is no mathematical proof that the parser recognizes the grammar I think
  it does.

## Prerequisites

In order to build the project you need to have a recent version of a
[D compiler][1] and [dub package and build manager][2] installed. Specific 
version requirements can be found in `dub.sdl`.

## Build

Execute `dub build` to build the project, or `dub test` to build and run unit
tests.

## Usage

The project includes a command-line interactive driver that invokes the parser.

You can build and run the project with a single command: `dub run`. Or you can
invoke it with `./build/dop-parser` after building it.

You will first be given instructions on how to define operators and then the
option to submit expressions for parsing. The parser responds to each submitted
expression with either a Lisp-list-like representation of the syntax tree, or
a syntax error.

Note that there is no scanner, so tokens are separated by whitespace.

## Compatibility

* You should be able to build the parser using any one of dmd, gdc and ldc.
* You should also be able to run it on any one of Windows, Linux and Mac OS X,
  although only the first two have been tested.

## How it works

The way the parser works once we know what fixity we're dealing with — and by
extension what's the precedence of the current token — is pretty standard. By
contrast I have yet to find a book, post or paper describing this disambiguation
scheme (it is very possible that I invented it) and thus, I'll include an
overview here:

### Definitions

1. *operand*: Any single token that has not been declared as an *operator*,
			  *initiator*, *terminator* or *separator*. It is intended to
			  represent literals like `b` or `42`.
2. *operator*: Any single token that has been declared as a *prefix*, *infix*,
			   or *postfix* operator, or a combination of these. The declaration
			   assigns certain attributes to the operator like its priority and
			   associativity.
3. *initiator*: Any single token that has been declared to begin a *confix* or
				*list-like* *expression*. The intention is for `(`, `[`, `{`,
				etc. to be used as *initiators*. The declaration ties it with a
				corresponding *terminator*.
4. *terminator*: Any single token that has been declared to end a *confix* or
				 *list-like* *expression*. The intention is for `)`, `]`, `}`,
				 etc. to be used as *terminators*. The declaration ties it with
				 a corresponding *initiator*.
5. *separator*: Any single token that has been declared to separate individual
				sub-expressions of a *list-like* structure. The intention is for
				`,` to be used as a *separator*. The declaration ties it with
				 a corresponding *initiator* and *terminator*.
6. *operable*: An *operand* or a group of tokens forming a *confix* or
			   *list-like* *expression*. In other words, an *expression* without
			   any leading or trailing *operators*.
7. *expression*: Any token or group of tokens that follows the usual rules for
				 building expressions from operators and operands. (e.g. E ⟶ E
				 infix\_op E, E ⟶ prefix\_op E, etc.)

### Disambiguation Scheme

Let's assume a special initiator token is inserted before the begin-of-input and
a special terminator one after the end-of-input. Now assume you see a token
other than *operator* and you look ahead until the next non-*operator* token.
There are 4 possibilities:

1.  If your first token was an *initiator* or *separator* and the second was a
	*terminator* or *separator*, then it's an error to have any *operators* in
	between.
2.  If your first token was an *initiator* or *separator* and the second was an
	*initiator* or *operand*, then you must interpret all operators between them
	as prefix ones. If you can't, you issue a syntax error.
3.  If your first token was a *terminator* or *operand* and the second was a
	*terminator* or *separator*, then you must interpret all operators between
	them as postfix ones. If you can't, you issue a syntax error.
4.  If your first token was a *terminator* or *operand* and the second was an
	*initiator* or *operand* then, unless you have juxtaposition defined, there
	has to be exactly one infix operator between them — possibly with postfix
	operators before it and prefix operators after it.

	So you find the first operator that can't be postfix and the last that can't
	be prefix (both from the left) and count the operators that *can* be infix
	between them:

	1. If there are more than one, the expression is ambiguous.
	2. If there is exactly one, you select it as the infix and interpret all
	   operators before it as postfix and all operators after it as prefix.
	3. If there are none. You consider juxtaposition:

		1. If it's not defined, you issue a syntax error.
		2. Otherwise, if the last non-prefix is exactly before the first
		   non-postfix, you act as if there was an infix operator between them
		   with the same attributes as juxtaposition.
		3. Otherwise, the expression is ambiguous.

### Examples

Consider the expression `foo ! % * ! $ + bar` where `foo` and `bar` are operands
and the operators have been declared according to the following table. Although
there are two candidate infix operators, only `*` can actually be interpreted as
such, because otherwise we would have a prefix operator (`$`) before an infix
one (`+`) which is a syntax error.

                --------------------------------------
                 prefix | v |   | v | v | v | v |
                  infix |   |   | v |   |   | v |
                postfix | v | v | v | v |   |   |
                --------------------------------------
                    foo | ! | % | * | ! | $ | + | bar
                              ^   |   |   ^
                              |   |   |   |
                              |   +-------|-----> potentially prefix
                              |       |   |
                      last non-prefix |   |
                                      |   |
    potentially postfix <-------------+   |
                                          |
                                 first non-postfix

                              ^           ^
                              |           |
          Only operators inside this range can be selected as infix.
                          Only one actually is.

## Mirrors

Currently the project exists in two different mirrors that are kept in sync:

1. <https://github.com/avnomad/dop-parser>
2. <https://bitbucket.org/avnomad/dop-parser>

The 2nd presents a slightly more accurate picture of the history. That's because
I've developed it using Mercurial and I've used a few features that aren't
available in Git. Although all the information is preserved by the hg-git
bridge, some commit meta-data will only be visible as part of the commit message
in GitHub.

## Future direction

The first step would be to add negative tests to complete the test suite and
reach 100% code coverage. In our case, this translates to tests ensuring correct
behaviour on input that contains syntax errors.

Then priorities and associativities need to be implemented for prefix and
postfix operators.

In the long run, more interesting features can be added, like expressions that
evaluate to operators instead of values.

## Contributing

In order to contribute, just fork the project and open a pull request in either
GitHub or BitBucket.

## Notes

- I've used Hg branches in a rather unusual way, in this project. [This][3] blog
  post attempts to explain how and why.
- This project uses [Semantic Versioning][4]. Since there is no stable public
  API yet, the standard only prescribes that major version should be 0, not when
  minor and patch versions should increase. So I increase the minor version when
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
