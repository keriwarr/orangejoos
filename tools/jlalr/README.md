# JLALR -- Grammar compiler

There are two tools provided:

`bnf_to_cfg.py` is a python script that compiles the BNF-style grammar (i.e. joos1w.bnf) into the CFG (context-free-grammar) file as specified on the CS444 site. To invoke it, use `python3 tools/jlalr/bnf_to_cfg.py grammar/joos1w.bnf`

Then, the Jlalr1 tool will compute an LALR(1) prediction table given the CFG file. To invoke it, use `make jlalr1 < grammar/joos1w.cfg`.