#!/bin/bash

file_name_test=$1

if make ; then
  :
else
  exit 1
fi

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

rm $failed_test_descr_file 2> /dev/null

stdlib=$(find $PUB_FOLDER/stdlib/2.0 -type f -name "*.java" -exec echo -n '{} ' \;)

do_test() {
  file=$1
  should_pass=$2
  args=$3 # to be passed to ./joosc
  context=$4 # will be printed next to the file name
  include_stdlib=${5:-true}
  includes=""

  if [[ $file != *"$file_name_test"* ]]; then
    return
  fi
  if [[ $include_stdlib = true ]]; then
    includes=$stdlib
  fi
  ./joosc $includes $file $args >/dev/null 2>/dev/null
  result=$?
  description=""

  if [[ $result = 42 && $should_pass = true ]]; then
    description="== ${RED}FAIL${NC}: ${file} ${context}"
    bad_fail=$((bad_fail + 1))
    echo "== ${RED}FAIL${NC}: ./joosc $includes $file $args -v" >> $failed_test_descr_file
  elif [[ $result = 0 && $should_pass = true ]]; then
    description="== ${GREEN}PASS${NC}: ${file} ${context}"
    correct_pass=$((correct_pass + 1))
  elif [[ $result = 42 && $should_pass = false ]]; then
    description="== ${GREEN}FAIL${NC}: ${file} ${context}"
    correct_fail=$((correct_fail + 1))
  elif [[ $result = 0  && $should_pass = false ]]; then
    description="== ${RED}PASS${NC}: ${file} ${context}"
    bad_pass=$((bad_pass + 1))
    echo "== ${RED}PASS${NC}: ./joosc $includes $file $args -v" >> $failed_test_descr_file
  else
    description="== ${RED}EROR${NC}: ${file} ${context}"
    errors=$((errors + 1))
    echo "== ${RED}EROR${NC}: ./joosc $includes $file $args -v" >> $failed_test_descr_file
  fi

  echo $description
}

# ----------------------------------------------------------------------------
# Run against test files scraped from
# https://www.student.cs.uwaterloo.ca/~cs444/joos.html
# ----------------------------------------------------------------------------

PASS_FILES=$(find ${TEST_FOLDER}/parser/valid -type f | grep "$file_name_test")
FAIL_FILES=$(find ${TEST_FOLDER}/parser/bad -type f | grep "$file_name_test")

for file in $PASS_FILES; do
  do_test $file true
done

for file in $FAIL_FILES; do
  do_test $file false
done

# ----------------------------------------------------------------------------
# Run against assignment test files, and std lib
# ----------------------------------------------------------------------------

regex="^\/\/ ?(([A-Z_0-9]+)\: ?)?(([A-Z_0-9]+, ?)*[A-Z_0-9]+),? *$"

for filename in `find ${PUB_FOLDER} -name "*.java" -type f | grep "$file_name_test" | sort`; do
  should_pass=true;
  # I believe "Je" stands for Joos Error
  if [[ $(basename $filename) == Je* ]]; then
    should_pass=false;
  fi

  executed_tagwords=()

  regex_lines=0
  while IFS='' read -r line || [[ -n "$line" ]]; do
    # Some testing files begin with a series of single line comments containing metadata
    if [[ $line == \/\/* ]]; then
      # Each line contains a list of tag-words, optionally prepended by the name of a JOOS dialect
      if [[ $line =~ $regex ]]; then
        regex_lines=$((regex_lines + 1))

        dialect="${BASH_REMATCH[2]}"
        tagwordlist="${BASH_REMATCH[3]// /}"
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
            if [[ $tagword = "${executed_tagwords[tagword_index]}" ]]; then
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
              do_test $filename $should_pass "-s weed" $tagword false
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
            JOOS1_INC_DEC)
              ;;
            ASSIGN_TO_FINAL_FIELD)
              ;;
            NON_NUMERIC_INC_DEC)
              ;;
            NON_NUMERIC_ARRAY_SIZE)
              ;;
            DUPLICATE_FIELD)
              ;;
            SINGLE_TYPE_IMPORT_CLASH_WITH_CLASS)
              ;;
            DIFFERENT_RETURN_TYPE)
              ;;
            ILLEGAL_THROWS_IN_REPLACE)
              ;;
            DUPLICATE_METHOD)
              ;;
            PROTECTED_REPLACE_PUBLIC)
              ;;
            CIRCULAR_INHERITANCE)
              ;;
            DUPLICATE_VARIABLE)
              ;;
            DUPLICATE_TYPE)
              ;;
            AMBIGUOUS_CLASS_NAME)
              ;;
            NON_EXISTING_PACKAGE)
              ;;
            PREFIX_RESOLVES_TO_TYPE)
              ;;
            PACKAGE_CLASH_WITH_TYPE)
              ;;
            UNRESOLVED_TYPE)
              ;;
            VARIABLE_OR_TYPE_NOT_FOUND)
              ;;
            TWO_SINGLE_TYPE_IMPORTS_CLASH)
              ;;
            CLASS_MUST_BE_ABSTRACT)
              ;;
            DUPLICATE_CONSTRUCTOR)
              ;;
            EXTENDS_FINAL_CLASS)
              ;;
            EXTENDS_NON_CLASS)
              ;;
            REPLACE_FINAL)
              ;;
            IMPLEMENTS_NON_INTERFACE)
              ;;
            REPEATED_INTERFACE)
              ;;
            STATIC_REPLACE_NONSTATIC)
              ;;
            NONSTATIC_REPLACE_STATIC)
              ;;
            JOOS1_IMPLICIT_THIS_CLASS_STATIC_METHOD)
              ;;
            JOOS1_ARRAY_METHOD_CALL)
              ;;
            PROTECTED_MEMBER_ACCESS)
              ;;
            THIS_IN_STATIC_CONTEXT)
              ;;
            VARIABLE_NOT_FOUND)
              ;;
            UNOP_TYPE)
              ;;
            NON_REFERENCE_RECEIVER)
              ;;
            ILLEGAL_FORWARD_FIELD_REFERENCE)
              ;;
            FIELD_NOT_FOUND)
              ;;
            INVALID_CAST)
              ;;
            NON_BOOLEAN_CONDITION)
              ;;
            BINOP_TYPE)
              ;;
            CONSTRUCTOR_NAME)
              ;;
            INSTANTIATE_ABSTRACT_CLASS)
              ;;
            INSTANTIATE_INTERFACE)
              ;;
            NON_JOOS_RETURN_TYPE)
              ;;
            STATIC_FIELD_LINKED_AS_NONSTATIC)
              ;;
            STATIC_METHOD_LINKED_AS_NONSTATIC)
              ;;
            PROTECTED_CONSTRUCTOR_INVOCATION)
              ;;
            NONSTATIC_FIELD_LINKED_AS_STATIC)
              ;;
            NONSTATIC_METHOD_LINKED_AS_STATIC)
              ;;
            VARIABLE_MIGHT_NOT_HAVE_BEEN_INITIALIZED)
              ;;
            MISSING_RETURN_STATEMENT)
              ;;
            JOOS1_LOCAL_VARIABLE_IN_OWN_INITIALIZER)
              ;;
            *)
              echo ""
              echo "${RED}EROR${NC}: unrecognized tagword: ${tagword} Please incorporate it into ${0}."
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
  if [[ $regex_lines == 0 ]]; then
    if [[ $filename = "${PUB_FOLDER}/assignment_testcases/a1"* ]]; then
      do_test $filename $should_pass "-s weed" "" false
    elif [[ $filename = "${PUB_FOLDER}/assignment_testcases/a2"* ]]; then
      do_test $filename $should_pass "-s nameresolution"
    else
      do_test $filename $should_pass
    fi
  fi
done

# ----------------------------------------------------------------------------
# Tally the results
# ----------------------------------------------------------------------------

echo ""
echo "=== FAILING TESTS ==="
echo ""

cat $failed_test_descr_file 2>/dev/null

echo ""
echo "=== RESULTS ==="
echo ""
echo "${GREEN}Correct${NC}: $((correct_pass + correct_fail))"
echo "${RED}Failed${NC}:  $((bad_pass + bad_fail))"
echo "${RED}Errors${NC}:  $((errors))"
