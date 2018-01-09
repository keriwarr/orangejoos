"""
grammer_compiler parses a BNF-style context-free grammar and generates a
variety of outputs.
 - LALR(1) specification
 - Tokens
"""

# TODO(joey): Currently this only parses the file and emits diagnostic
# information. For example, print all terminal tokens to help identify
# what the grammar specifies as LEXMES.

import re
import sys

# def parse_expansion(rule):
#     # TODO(joey): Possibly return the expansion versions.
#     expansions_openings = []
#     for i, ch in enumerate(rule):
#         if ch == '(' or ch == '[':
#             expansions_openings.append((i, ch))

#     expansions = []
#     if len(expansions_openings) > 0:
#         expansion = expansions_openings.pop(0)
#         for i, ch in enumerate(reversed(rule)):
#             if (expansion[1] == '(' and ch == ')') or (expansion[1] == '[' and ch == ']'):
#                 expansions.append((expansion[0], len(rule) - i))
#                 if len(expansions_openings) == 0:
#                     break
#                 expansion = expansions_openings.pop(0)
#     return expansions


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

    section = "TOKENS"
    current_section = None

    # Scan through each line of the grammar.
    for line in lines:
        # Remove trailing whitespace and newline. These should not impact
        # the grammar.
        line = line.rstrip()

        # Filter the section. This is to make a distinction between
        # tokens and grammar rules.
        pragma = re.search(r'^# PRAGMA\((.*)\)$', line)
        if pragma is not None:
            current_section = pragma.group(1)
            continue
        elif current_section != section:
            continue

        is_one_of = False

        # Skip empty lines.
        if line == "":
            continue
        # Skip comments.
        if re.search(r'^ *#', line) is not None:
            continue
        # We either have a continuation of a rule or the definition of a
        # new rule.
        if line[:2] == "  ":
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
                tokens.add(token)

            productions[current_production].append(rule)
            continue

        rule_line = re.search(r'(.*):( one of)?$', line)
        if rule_line is not None:
            current_production = rule_line.group(1)
            is_one_of = len(rule_line.groups()) > 2
            productions[current_production] = []
        else:
            print("BAD LINE: " + line)

    print("productions: %s" % productions)
    print("tokens: %s" % "\n".join(sorted(tokens - set(productions.keys()))))

