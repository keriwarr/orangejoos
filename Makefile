
CRYSTAL_SRCS := $(find src -name '*.cr')
JLALR_SRCS := $(find tools/jlalr -name '*.java')

.PHONY: orangejoos
orangejoos: ## orangejoos is the general compiler.
orangejoos: $(CRYSTAL_SRCS)
	crystal build ./src/orangejoos.cr

jlalr1: ## JLALR1 is the LALR(1) prediction table generated, provided by CS444.
jlalr1: $(JLALR_SRCS)
	javac ./tools/jlalr/Jlalr1.java
	java -cp ./tools/ jlalr.Jlalr1

.PHONY: clean
clean:
	find . -name '*.class' | xargs -I{} rm {}
	rm -f joosc.jar
	rm -f orangejoos orangejoos.dwarf

grammar/joos1w.cfg: ## The context-free grammar file.
grammar/joos1w.cfg: grammar/joos1w.bnf tools/jlalr/bnf_to_cfg.py
	python3 tools/jlalr/bnf_to_cfg.py grammar/joos1w.bnf > $@

grammar/joos1w.lr1: ## The LALR(1) prediction table.
grammar/joos1w.lr1: grammar/joos1w.cfg jlalr1
	java -cp ./tools/ jlalr.Jlalr1 < grammar/joos1w.cfg > $@
