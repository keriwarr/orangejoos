# orangejoos

<<<<<<< HEAD
A Joos1W compiler in Kotlin. Joos1W is a subset of Java 1.3.


## Usage


```bash
make build && ./run.sh <FILE>
```


## File structure


```
test/parser
  Scraped test cases for Joos1W programs.
tools/joos_scraper
  A scraper to fetch syntactically valid Joos1W programs from the course page.
```

## TODOs


### Tokenizer

- Read JLS2 for a specification of tokens.
- Create a tokenizer;


### Parser and syntax analysis

- Clean up the Java grammar ([grammar/joos1s.bnf])
- Write a generator to generate a LALR(1) syntax as specified in CS 241
  from the BNF grammar.
- Hook up the provided LALR(1) parser, in order to generate a parser
  DFA.
- Use the parser DFA to parse the tokens.
- Read through the JLS spec for compiler errors. That is, errors that
  are not explicit in the grammar.

[grammar/joos1s.bnf]: grammar/joos1s.bnf


## Resources

Java Specifications: Version 1 and Version 2.

Modern Compiler Implementation in Java, Appel.
=======
TODO: Write a description here

## Installation

TODO: Write installation instructions here

## Usage

TODO: Write usage instructions here

## Development

TODO: Write development instructions here

## Contributing

1. Fork it ( https://github.com/[your-github-name]/orangejoos/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request

## Contributors

- [[your-github-name]](https://github.com/[your-github-name]) slantin - creator, maintainer
>>>>>>> 1fc7c80... crystal init
