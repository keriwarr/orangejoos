#!/bin/bash

make

FAIL_FILES=$(find test/parser/bad -type f)
PASS_FILES=$(find test/parser/valid -type f)

# Terminal colours.
RED=`tput setaf 1`
GREEN=`tput setaf 2`
NC=`tput sgr0` # no colour

correct_fail=0
correct_pass=0
bad_fail=0
bad_pass=0
errors=0

for file in $FAIL_FILES; do
  RESULT=$(./joosc $file >/dev/null 2>/dev/null)
  result=$?
  if [[ $result = 42 ]]; then
    echo "== ${GREEN}FAIL${NC}: ${file}"
    correct_fail=$((correct_fail + 1))
  elif [[ $result = 0 ]]; then
    echo "== ${RED}PASS${NC}: ${file}"
    bad_pass=$((bad_pass + 1))
  else
    echo "== ${RED}ERROR${NC}: ${file}"
    errors=$((errors + 1))
  fi
done

for file in $PASS_FILES; do
  RESULT=$(./joosc $file >/dev/null 2>/dev/null)
  result=$?
  if [[ $result = 42 ]]; then
    echo "== ${RED}FAIL${NC}: ${file}"
    bad_fail=$((bad_fail + 1))
  elif [[ $result = 0 ]]; then
    echo "== ${GREEN}PASS${NC}: ${file}"
    correct_pass=$((correct_pass + 1))
  else
    echo "== ${RED}ERROR${NC}: ${file}"
    errors=$((errors + 1))
  fi
done

regex="^\/\/ (([A-Z_0-9]+)\: ?)?(([A-Z_0-9]+,)*[A-Z_0-9]+)$"

for filename in `find pub -name "*.java" -type f`; do
  should_pass=true;
  if [[ $(basename $filename) == Je* ]]; then
    should_pass=false;
  fi

  regex_lines=0
  while IFS='' read -r line || [[ -n "$line" ]]; do
    if [[ $line == \/\/\ * ]]; then
      if [[ $line =~ $regex ]]; then
        regex_lines=$((regex_lines + 1))

        language="${BASH_REMATCH[2]}"
        descriptorlist="${BASH_REMATCH[3]}"
        IFS=', ' read -r -a descriptors <<< "$descriptorlist"

        if [ -z "$language" ]; then
          :
        elif [[ $language == "JOOS1" ]]; then
          :
        elif [[ $language == "JOOS2" ]]; then
          :
        elif [[ $language == "JAVAC" ]]; then
          break
        else
          break
        fi

        # echo $filename
        for index in "${!descriptors[@]}"
        do
          case "${descriptors[index]}" in
            PARSER_WEEDER)
              RESULT=$(./joosc $filename -s weed >/dev/null 2>/dev/null)
              result=$?
              if $should_pass; then
                if [[ $result = 42 ]]; then
                  echo "== ${RED}FAIL${NC}: ${filename}"
                  bad_fail=$((bad_fail + 1))
                elif [[ $result = 0 ]]; then
                  echo "== ${GREEN}PASS${NC}: ${filename}"
                  correct_pass=$((correct_pass + 1))
                else
                  echo "== ${RED}ERROR${NC}: ${filename}"
                  errors=$((errors + 1))
                fi
              else
                if [[ $result = 42 ]]; then
                  echo "== ${GREEN}FAIL${NC}: ${filename}"
                  correct_fail=$((correct_fail + 1))
                elif [[ $result = 0 ]]; then
                  echo "== ${RED}PASS${NC}: ${filename}"
                  bad_pass=$((bad_pass + 1))
                else
                  echo "== ${RED}ERROR${NC}: ${filename}"
                  errors=$((errors + 1))
                fi
              fi
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
            *)
              ;;
          esac
        done
      fi
    else
      break
    fi
  done < $filename

  if [[ $regex_lines == 0 ]]; then
    RESULT=$(./joosc $filename >/dev/null 2>/dev/null)
    result=$?
    if $should_pass; then
      if [[ $result = 42 ]]; then
        echo "== ${RED}FAIL${NC}: ${filename}"
        bad_fail=$((bad_fail + 1))
      elif [[ $result = 0 ]]; then
        echo "== ${GREEN}PASS${NC}: ${filename}"
        correct_pass=$((correct_pass + 1))
      else
        echo "== ${RED}ERROR${NC}: ${filename}"
        errors=$((errors + 1))
      fi
    else
      if [[ $result = 42 ]]; then
        echo "== ${GREEN}FAIL${NC}: ${filename}"
        correct_fail=$((correct_fail + 1))
      elif [[ $result = 0 ]]; then
        echo "== ${RED}PASS${NC}: ${filename}"
        bad_pass=$((bad_pass + 1))
      else
        echo "== ${RED}ERROR${NC}: ${filename}"
        errors=$((errors + 1))
      fi
    fi
  fi
done



echo "=== RESULTS ==="
echo "Correct: $((correct_pass + correct_fail))"
echo "Failed: $((bad_pass + bad_fail))"
echo "Errors: $((errors))"
