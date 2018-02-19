#!/bin/bash

# If any argument is passed, run extra tests
all_tests=false
if [[ $# -gt 0 ]]; then
  all_tests=true
fi

make

TEST_FOLDER="test"
PUB_FOLDER="pub"

# Terminal colours.
RED=`tput setaf 1`
GREEN=`tput setaf 2`
NC=`tput sgr0` # no colour

correct_fail=0
correct_pass=0
bad_fail=0
bad_pass=0
errors=0

failed_test_descr_file="failed_tests.tmp"

rm $failed_test_descr_file

do_test() {
  file=$1
  should_pass=$2
  args=$3 # to be passed to ./joosc
  context=$4 # will be printed next to the file name

  RESULT=$(./joosc $file $args >/dev/null 2>/dev/null)
  result=$?
  description=""

  if [[ $result = 42 && $should_pass = true ]]; then
    description="== ${RED}FAIL${NC}: ${file} ${context}"
    bad_fail=$((bad_fail + 1))
    echo "== ${RED}FAIL${NC}: ./joosc $file $args" >> $failed_test_descr_file
  elif [[ $result = 0 && $should_pass = true ]]; then
    description="== ${GREEN}PASS${NC}: ${file} ${context}"
    correct_pass=$((correct_pass + 1))
  elif [[ $result = 42 && $should_pass = false ]]; then
    description="== ${GREEN}FAIL${NC}: ${file} ${context}"
    correct_fail=$((correct_fail + 1))
  elif [[ $result = 0  && $should_pass = false ]]; then
    description="== ${RED}PASS${NC}: ${file} ${context}"
    bad_pass=$((bad_pass + 1))
    echo "== ${RED}PASS${NC}: ./joosc $file $args" >> $failed_test_descr_file
  else
    description="== ${RED}EROR${NC}: ${file} ${context}"
    errors=$((errors + 1))
    echo "== ${RED}EROR${NC}: ./joosc $file $args" >> $failed_test_descr_file
  fi

  echo $description
}

# ----------------------------------------------------------------------------
# Run against test files scraped from
# https://www.student.cs.uwaterloo.ca/~cs444/joos.html
# ----------------------------------------------------------------------------

PASS_FILES=$(find ${TEST_FOLDER}/parser/valid -type f)
FAIL_FILES=$(find ${TEST_FOLDER}/parser/bad -type f)

for file in $PASS_FILES; do
  do_test $file true
done

for file in $FAIL_FILES; do
  do_test $file false
done

# ----------------------------------------------------------------------------
# Run against assignment test files, and std lib
# ----------------------------------------------------------------------------

regex="^\/\/ (([A-Z_0-9]+)\: ?)?(([A-Z_0-9]+,)*[A-Z_0-9]+)$"

for filename in `find ${PUB_FOLDER} -name "*.java" -type f | sort`; do
  should_pass=true;
  # I believe "Je" stands for Joos Error
  if [[ $(basename $filename) == Je* ]]; then
    should_pass=false;
  fi

  executed_tagwords=()

  regex_lines=0
  while IFS='' read -r line || [[ -n "$line" ]]; do
    # Some testing files begin with a series of single line comments containing metadata
    if [[ $line == \/\/\ * ]]; then
      # Each line contains a list of tag-words, optionally prepended by the name of a JOOS dialect
      if [[ $line =~ $regex ]]; then
        regex_lines=$((regex_lines + 1))

        dialect="${BASH_REMATCH[2]}"
        tagwordlist="${BASH_REMATCH[3]}"
        IFS=',' read -r -a tagwords <<< "$tagwordlist"

        if [ -z "$dialect" ]; then
          # If there's no dialect specified, assume the tagwords apply
          :
        elif [[ $dialect == "JOOS1" ]]; then
          # If the dialect is JOOS1, assume it applies
          # TODO: does this require correction?
          :
        elif [[ $dialect == "JOOS2" ]]; then
          # If the dialect is JOOS2, assume it applies
          # TODO: does this require correction?
          :
        elif [[ $dialect == "JAVAC" ]]; then
          # If the dialect is JAVAC, assume it doesn't apply
          break
        else
          echo ""
          echo "${RED}EROR${NC}: unrecognized dialect: ${dialect}. Please incorporate it into ${0}."
          echo ""
          exit 1
        fi

        for index in "${!tagwords[@]}"; do
          tagword="${tagwords[index]}"
          # Each tagword can appear multiple times for separate dialects.
          # Have we already seen this tagword?
          already_executed=false
          for tagword_index in "${!executed_tagwords[@]}"; do
            if [[ $tagword -eq "${executed_tagwords[tagword_index]}" ]]; then
              already_executed=true
            fi
          done
          if $already_executed; then
            continue
          fi

          executed_tagwords+=($tagword)

          case $tagword in
            PARSER_WEEDER)
              # I am interpreting "PARSER_WEEDER" as: should have either passed or failed by the end of the weeding stage
              do_test $filename $should_pass "-s weed" $tagword
              ;;
            CODE_GENERATION)
              ;;
            TYPE_CHECKING)
              ;;
            ENVIRONMENTS)
              ;;
            HIERARCHY)
              ;;
            RESOURCES)
              ;;
            REACHABILITY)
              ;;
            JOOS1_STATIC_FIELD_DECLARATION)
              ;;
            PARSER_EXCEPTION)
              ;;
            DISAMBIGUATION)
              ;;
            JOOS1_THIS_CALL)
              ;;
            CIRCULAR_CONSTRUCTOR_INVOCATION)
              ;;
            JOOS1_MULTI_ARRAY)
              ;;
            ASSIGN_TYPE)
              ;;
            AMBIGUOUS_OVERLOADING)
              ;;
            JOOS1_INC_DEC)
              ;;
            ASSIGN_TO_ARRAY_LENGTH)
              ;;
            JOOS1_EXPLICIT_SUPER_CALL)
              ;;
            THIS_BEFORE_SUPER_CALL)
              ;;
            NO_MATCHING_CONSTRUCTOR_FOUND)
              ;;
            JOOS1_THROW)
              ;;
            ILLEGAL_THROWS)
              ;;
            UNREACHABLE_STATEMENT)
              ;;
            ABSTRACT_FINAL_CLASS)
              ;;
            ABSTRACT_METHOD_FINAL_OR_STATIC)
              ;;
            ABSTRACT_METHOD_BODY)
              ;;
            SYNTAX_ERROR)
              ;;
            INVALID_SOURCE_FILE_NAME)
              ;;
            LEXER_EXCEPTION)
              ;;
            JOOS1_FINAL_FIELD_DECLARATION)
              ;;
            MISSING_FINAL_FIELD_INITIALIZER)
              ;;
            INVALID_INSTANCEOF)
              ;;
            VOID_TYPE_NOT_RETURN_TYPE)
              ;;
            VOID_TYPE_INSTANCEOF)
              ;;
            INVALID_INTEGER)
              ;;
            JOOS1_INTERFACE)
              ;;
            INTERFACE_CONSTRUCTOR)
              ;;
            INTERFACE_FIELD)
              ;;
            STATIC_OR_FINAL_INTERFACE_METHOD)
              ;;
            INTERFACE_METHOD_WITH_BODY)
              ;;
            NON_ABSTRACT_METHOD_BODY)
              ;;
            STATIC_FINAL_METHOD)
              ;;
            SUPER_CALL_NOT_FIRST_STATEMENT)
              ;;
            THIS_CALL_NOT_FIRST_STATEMENT)
              ;;
            VOID_TYPE_ARRAY)
              ;;
            VOID_TYPE_CAST)
              ;;
            VOID_TYPE_FIELD)
              ;;
            VOID_TYPE_VARIABLE)
              ;;
            DEFINITE_ASSIGNMENT)
              ;;
            JOOS1_OMITTED_LOCAL_INITIALIZER)
              ;;
            TYPE_LINKING)
              ;;
            NO_MATCHING_METHOD_FOUND)
              ;;
            JOOS1_CLOSEST_MATCH_OVERLOADING)
              ;;
            *)
              echo ""
              echo "${RED}EROR${NC}: unrecognized tagword: ${tagword}. Please incorporate it into ${0}."
              echo ""
              exit 1
          esac
        done
      fi
    else
      break
    fi
  done < $filename

  # No metadata/tagwords? Test it without any arguments.
  if [[ $all_tests == true && $regex_lines == 0 ]]; then
    do_test $filename $should_pass
  fi
done

# ----------------------------------------------------------------------------
# Tally the results
# ----------------------------------------------------------------------------

echo ""
echo "=== FAILING TESTS ==="
echo ""

cat $failed_test_descr_file

echo ""
echo "=== RESULTS ==="
echo ""
echo "${GREEN}Correct${NC}: $((correct_pass + correct_fail))"
echo "${RED}Failed${NC}:  $((bad_pass + bad_fail))"
echo "${RED}Errors${NC}:  $((errors))"
