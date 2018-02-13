#!/bin/bash

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


echo "=== RESULTS ==="
echo "Correct: $((correct_pass + correct_fail))"
echo "Failed: $((bad_pass + bad_fail))"
echo "Errors: $((errors))"
