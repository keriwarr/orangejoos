
CRYSTAL_SRCS := $(shell find ./src -name '*.cr')
JLALR_SRCS := $(shell find tools/jlalr -name '*.java')

default: joosc

joosc: ## joosc is the general compiler.
joosc: $(CRYSTAL_SRCS) grammar/joos1w.lr1
	crystal build ./src/joosc.cr

orangejoos: ## orangejoos is the general compiler with debug options.
orangejoos: $(CRYSTAL_SRCS) grammar/joos1w.lr1
	crystal build ./src/orangejoos.cr

.PHONY: jlalr1
jlalr1:
jlalr1: tools/jlalr/Jlalr1.class

tools/jlalr/Jlalr1.class: ## JLALR1 is the LALR(1) prediction table generated, provided by CS444.
tools/jlalr/Jlalr1.class: $(JLALR_SRCS)
	javac ./tools/jlalr/Jlalr1.java

.PHONY: clean
clean:
	find . -name '*.class' | xargs -I{} rm {}
	rm -f joosc.jar
	rm -f orangejoos orangejoos.dwarf
	rm -f orangejoos.zip
	rm -f joosc joosc.dwarf
	rm -f failed_tests.tmp
	rm -f grammar/joos1w.lr1
	rm -f grammar/joos1w.cfg

grammar/joos1w.cfg: ## The context-free grammar file.
grammar/joos1w.cfg: grammar/joos1w.bnf tools/jlalr/bnf_to_cfg.py
	python3 tools/jlalr/bnf_to_cfg.py grammar/joos1w.bnf > $@

grammar/joos1w.lr1: ## The LALR(1) prediction table.
grammar/joos1w.lr1: grammar/joos1w.cfg tools/jlalr/Jlalr1.class
	java -cp ./tools/ jlalr.Jlalr1 < grammar/joos1w.cfg > $@

.PHONY: orangejoos.zip
orangejoos.zip: ## Zip up the compiler for submission on marmoset.
orangejoos.zip: clean
	zip -r $@ . -x orangejoos.zip .git/\* .idea/\* docs/\* joosc orangejoos orangejoos.dwarf joosc.dwarf pub/\* test/\*
