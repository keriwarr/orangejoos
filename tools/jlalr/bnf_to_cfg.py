"""
bnf_to_cfg parses a BNF-style context-free grammar and generates the CFG
(context-free-grammar) specification required by the LALR(1) prediction
table generator.

The CFG gramamr is as specified for CS444
(https://www.student.cs.uwaterloo.ca/~cs444/jlalr/cfg.html) and used by
the provided tool.

The output format is:
    # of terminal tokens
    Terminal tokens (one per line)
    # of non-terminal tokens
    Non-terminal tokens (one per line)
    Starting symbol (alwyas Goal)
    # of production rules
    Production rules (one per line, in the form "LHS RHS...")
"""

import re
import sys


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("""Usage: pass the grammar file to parse.

        For example,

                python3 {filename} joos1w.bnf""".format(filename=sys.argv[0]))
        sys.exit(1)

    input_file = sys.argv[1]

    lines = None
    with open(input_file, 'r') as file:
        lines = file.readlines()


    productions = {}
    current_production = None
    tokens = set()
    rhs = set()

    is_one_of = False
    is_tokens_rule = False

    # Scan through each line of the grammar.
    for line in lines:
        # Remove trailing whitespace and newline. These should not impact
        # the grammar.
        line = line.rstrip()

        # Skip empty lines.
        if line == "":
            continue
        # Skip comments.
        if re.search(r'^ *#', line) is not None:
            continue
        # We either have a continuation of a rule or the definition of a
        # new rule. This first statement is when we have a continuation
        # of a rule. (i.e. another RHS for a production rule)
        if line[:2] == "  ":
            # XXX: do not record any of the terminal token sets. These
            # rules are not used in produced CFG file at all.
            if is_tokens_rule:
                continue

            rule = line.strip()

            if is_one_of:
                tks = rule.split(" ")
                productions[current_production] += tks
                continue

            # Collection all the tokens.
            tks = rule.split(' ')
            for token in tks:
                # Ignore the optional modifier on the token for now.
                if token[-1] == '?':
                    token = token[:-1]
                if is_tokens_rule:
                    tokens.add(token)
                else:
                    rhs.add(token)

            productions[current_production].append(rule)
            continue

        is_one_of = False
        is_tokens_rule = False
        rule_line = re.search(r'(.*):( one of)?$', line)
        if rule_line is not None:
            current_production = rule_line.group(1)
            tokens_prefix = re.search(r'^TOKENS=(.*)', current_production)
            if tokens_prefix is not None:
                current_production = tokens_prefix.group(1)
                is_tokens_rule = True
                # XXX: do not record any of the terminal token sets. These
                # rules are not used in produced CFG file at all.
                if is_tokens_rule:
                    continue
            else:
                is_tokens_rule = False

            is_one_of = len(rule_line.groups()) > 2
            productions[current_production] = []
        else:
            print("BAD LINE: " + line)

    # print("productions: %s" % productions)
    # missing_rhs_rules = (rhs - set(productions.keys()) - tokens)
    # print("missing RHS: %s" % "\n".join(sorted(missing_rhs_rules)))
    # print("tokens: %s" % "\n".join(sorted(tokens)))

    # Substitute all optional grammar rules. This means any token with a
    # trailing ? will generate two new rules: one with the token and one
    # without it. This will need to be done continously until all
    # optionals are resolved. For example:
    #
    #   CompilationUnit:
    #     PackageDeclaration? ImportDeclarations? TypeDeclarations?
    #
    #  becomes
    #
    #   CompilationUnit:
    #     PackageDeclaration ImportDeclarations? TypeDeclarations?
    #     ImportDeclarations? TypeDeclarations?
    #
    #  which continues to expand.
    #
    # FIXME(joey): If this generates empty string RHS I am not sure if
    # those should continue through.

    def has_optional_rule(rules):
        return any(['?' in rule for rule in rules])

    for lhs in productions.keys():
        while has_optional_rule(productions[lhs]):
            for i, rule in enumerate(productions[lhs]):
                if '?' not in rule:
                    continue

                # print("RULE WITH OPTIONAL!")
                # print("LHS: %s" % lhs)
                # print("Rule: %s" % rule)
                # Adding the trailing space allows the following regex
                # to clean out a trailing space from the token even if
                # the token is the last sequence of characters.
                rule = rule + ' '
                results = re.search(r'(\S+\?) ', rule)
                # FIXME(joey): results should never be None here.
                if results is None:
                    raise "Oops"
                    # print("UH OH: %s" % rule)
                replacing = results.group(1)
                rule_without_token = rule.replace(replacing, '')
                rule_with_token = rule.replace(replacing, replacing[:-1])
                # print("Without token: %s" % rule_without_token)
                # print("W token: %s" % rule_with_token)
                productions[lhs].pop(i)
                productions[lhs].append(rule_with_token)
                productions[lhs].append(rule_without_token)
                break


    terminals = sorted((rhs - set(productions.keys())) | tokens)
    nonterminals = productions.keys()
    # Collect all production rules.
    production_rules = []
    for lhs, rules in productions.items():
        for rule in rules:
            production_rules.append("%s %s" % (lhs, rule))

    # Print out the .cfg formatted file (https://www.student.cs.uwaterloo.ca/~cs444/jlalr/cfg.html)
    # count of terminals
    print(len(terminals))
    # all the terminals
    print("\n".join(terminals))
    # count of non-terminals
    print(len(nonterminals))
    # all the non-terminals
    print("\n".join(nonterminals))
    # start symbol
    print("Goal")
    # count of production rules
    print(len(production_rules))
    # all production rules
    print("\n".join(production_rules))

