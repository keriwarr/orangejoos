
# By default, we are not compiling on marmoset. This is overwritten by
# `assignment.mk`
MARMOSET := false

# When compiling, if an assignment target (`ASSN`) is not provided, such
# as in marmoset, then `assignment.mk` will be included. This
# includes `ASSN := Ax`. This allows assignment specific marmoset
# zip creation.
ifndef ASSN

# If assignment.mk does not exist, this is being run locally
# without `ASSN` incorrectly.
ifeq ("","$(wildcard ./assignment.mk)")
$(error "Please provide an assignment target. For example: `make joosc ASSN=A2`")
endif

include assignment.mk
endif

# TODO(joey): Check that `ASSN` is valid.

CRYSTAL_SRCS := $(shell find ./src -name '*.cr')
JLALR_SRCS := $(shell find tools/jlalr -name '*.java')

default: joosc

.PHONY: all
all: joosc orangejoos docs

joosc: ## joosc is the general compiler.
joosc: $(CRYSTAL_SRCS) grammar/joos1w.lr1
	crystal build ./src/joosc.cr -D$(ASSN)

orangejoos: ## orangejoos is the general compiler with debug options.
orangejoos: $(CRYSTAL_SRCS) grammar/joos1w.lr1
	crystal build ./src/orangejoos.cr

.PHONY: jlalr1
jlalr1:
jlalr1: tools/jlalr/Jlalr1.class

tools/jlalr/Jlalr1.class: ## JLALR1 is the LALR(1) prediction table generated, provided by CS444.
tools/jlalr/Jlalr1.class: $(JLALR_SRCS)
	javac ./tools/jlalr/Jlalr1.java

.PHONY: clean-light
clean-light: ## Removes standard binary results.
clean-light:
	rm -f orangejoos orangejoos.dwarf
	rm -f orangejoos.zip
	rm -f joosc joosc.dwarf
	rm -f failed_tests.tmp
	rm -f assignment.mk

.PHONY: clean
clean: ## Removes all built results.
clean: clean-light
	find . -name '*.class' | xargs -I{} rm {}
	rm -f joosc.jar
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
orangejoos.zip: clean-light grammar/joos1w.lr1
	echo "export ASSN := $(ASSN)\nexportMARMOSET := true" > assignment.mk
	zip -r $@ . -x orangejoos.zip .git/\* .idea/\* docs/\* joosc orangejoos orangejoos.dwarf joosc.dwarf pub/\* test/\*
	rm -rf assignment.mk


docs:
	crystal docs
