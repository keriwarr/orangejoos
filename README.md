# Orangejoos

A compiler JOOS1W, written in the Crystal lang.

## Installation

Install crystal. `brew install crystal-lang`.

## Usage

TODO: Write usage instructions here

## Development

## Progress


### Tokenizer

- [x] Read JLS2 for a specification of tokens.
  - Requires a more thorough read through for syntax analysis.
- [x] Create a tokenizer ([src/scanner.cr](/src/scanner.cr)).


### Parser and syntax analysis

- [x] Copy-pasta the Java grammar from the JLS
  ([grammar/joos1s.bnf](grammar/joos1s.bnf)).
  - May require a more thorough read through.
- [x] Write a script to convert the JLS BNF-style notation to
  [CFG](https://www.student.cs.uwaterloo.ca/~cs444/jlalr/cfg.html).
- [x] Hook up the provided LALR(1) tool to generate an [LALR(1)
  table](https://www.student.cs.uwaterloo.ca/~cs444/jlalr/lr1.html) from
  the CFG file.
- [ ] Read in the prediction table into the compiler.
- [ ] Parse a list of tokens using the prediction table. Refer to the
  Compilers textbook for an algorithm for a top-down (or bottom-up??)
  parsing with a prediction table with a stack.
- [ ] Add syntatical analysis not included in the grammar. For example:
  - Checking for permitted valid modifiers on fields or methods.
  - Checking the existance of a main function.
  - Refer to the JLS1 spec to find more rules.
- [ ] Create a stage to convert the parse-tree into a usable abstract
  syntax tree. Due to the structure of the grammar, there are lots of
  intermediary rules, hence the final result should have these rules
  reduced.


## Resources

- Java Specifications: Version 1 and Version 2.
- Modern Compiler Implementation in Java, Appel.

