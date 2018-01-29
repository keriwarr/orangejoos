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
- [x] Read in the prediction table into the compiler.
- [x] Parse a list of tokens using the prediction table. Refer to the
  Compilers textbook for an algorithm for a bottom-up
  parsing with a prediction table and a stack.
- [ ] Add syntatical analysis not included in the grammar. See the section below for some checks.
- [ ] Create a stage to convert the parse-tree into a usable abstract
  syntax tree. Due to the structure of the grammar, there are lots of
  intermediary rules, hence the final result should have these rules
  reduced.

#### Addtional syntax analysis (i.e. weeding)

From the assignment page:

- [ ] All characters in the input program must be in the range of 7-bit ASCII (0 to 127).
- [ ] A class cannot be both abstract and final.
- [ ] A method has a body if and only if it is neither abstract nor native.
- [ ] An abstract method cannot be static or final.
- [ ] A static method cannot be final.
- [ ] A native method must be static.
- [ ] The type void may only be used as the return type of a method.
- [ ] A formal parameter of a method must not have an initializer.
- [ ] A class/interface must be declared in a .java file with the same base name as the class/interface.
- [ ] An interface cannot contain fields or constructors.
- [ ] An interface method cannot be static, final, or native.
- [ ] An interface method cannot have a body.
- [ ] Every class must contain at least one explicit constructor.
- [ ] No field can be final.
- [ ] No multidimensional array types or multidimensional array creation expressions are allowed.
- [ ] A method or constructor must not contain explicit this() or super() calls.


From the specification:

- [ ] Checking for permitted valid modifiers on fields, methods,
  classes, and interfaces.
- [ ] Check for the existance of a main function and the correct
  signature.
- [ ] Check the size of numbers are valid.
- [ ] Check the length of character literals (should happen in scanning).
- [ ] Repeated function definitions.
- Refer to the JLS1 spec to find more rules.


## Resources

- Java Specifications: Version 1 and Version 2.
- Modern Compiler Implementation in Java, Appel.

