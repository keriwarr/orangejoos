#!/bin/bash

file_name_test=$1

if make ASSN=A_NONE ; then
  :
else
  exit 1
fi

failed_test_descr_file="failed_tests.tmp"

rm $failed_test_descr_file 2> /dev/null


TEST_FOLDER="test"
PUB_FOLDER="pub"

stdlib2=$(find $PUB_FOLDER/stdlib/2.0 -type f -name "*.java" -exec echo -n '{} ' \;)
stdlib3=$(find $PUB_FOLDER/stdlib/3.0 -type f -name "*.java" -exec echo -n '{} ' \;)
stdlib4=$(find $PUB_FOLDER/stdlib/4.0 -type f -name "*.java" -exec echo -n '{} ' \;)
stdlib5=$(find $PUB_FOLDER/stdlib/5.0 -type f -name "*.java" -exec echo -n '{} ' \;)

# Terminal colours.
RED=`tput setaf 1`
GREEN=`tput setaf 2`
NC=`tput sgr0` # no colour

correct_fail=0
correct_pass=0
bad_fail=0
bad_pass=0
errors=0

do_test() {
  file=$1
  should_pass=$2
  args=$3
  stdlib="$4"

  if [[ $file != *"$file_name_test"* ]]; then
    return
  fi

  ./joosc $stdlib $file $args >/dev/null 2>/dev/null
  result=$?
  description=""

  if [[ $result = 42 && $should_pass = true ]]; then
    description="== ${RED}FAIL${NC}: ${file}"
    bad_fail=$((bad_fail + 1))
    echo "== ${RED}FAIL${NC}: ./joosc $stdlib $file $args -v" >> $failed_test_descr_file
  elif [[ $result = 0 && $should_pass = true ]]; then
    description="== ${GREEN}PASS${NC}: ${file}"
    correct_pass=$((correct_pass + 1))
  elif [[ $result = 42 && $should_pass = false ]]; then
    description="== ${GREEN}FAIL${NC}: ${file}"
    correct_fail=$((correct_fail + 1))
  elif [[ $result = 0  && $should_pass = false ]]; then
    description="== ${RED}PASS${NC}: ${file}"
    bad_pass=$((bad_pass + 1))
    echo "== ${RED}PASS${NC}: ./joosc $stdlib $file $args -v" >> $failed_test_descr_file
  else
    description="== ${RED}EROR${NC}: ${file}"
    errors=$((errors + 1))
    echo "== ${RED}EROR${NC}: ./joosc $stdlib $file $args -v" >> $failed_test_descr_file
  fi

  echo $description
}

# ----------------------------------------------------------------------------
# Run against test files scraped from
# https://www.student.cs.uwaterloo.ca/~cs444/joos.html
# ----------------------------------------------------------------------------

PASS_FILES=$(find ${TEST_FOLDER}/parser/valid -type f | grep "$file_name_test" | sort)
FAIL_FILES=$(find ${TEST_FOLDER}/parser/bad -type f | grep "$file_name_test" | sort)

for filename in $PASS_FILES; do
  do_test $filename true "-s weed"
  do_test $filename true "-s nameresolution" "$stdlib2"
done

for filename in $FAIL_FILES; do
  do_test $filename false "-s weed"
  do_test $filename false "-s nameresolution" "$stdlib2"
done

# ----------------------------------------------------------------------------
# Run against assignment test files, and std lib
# ----------------------------------------------------------------------------

for filename in `find ${PUB_FOLDER}/assignment_testcases/a1 -name "*.java" -type f | grep "$file_name_test" | sort`; do
  should_pass=true;
  # I believe "Je" stands for Joos Error
  if [[ $(basename $filename) == Je* ]]; then
    should_pass=false;
  fi

  do_test $filename $should_pass "-s weed"
done

for filename in `find ${PUB_FOLDER}/assignment_testcases/a2 -name "*.java" -type f | grep "$file_name_test" | sort`; do
  should_pass=true;
  if [[ $(basename $filename) == Je* ]]; then
    should_pass=false;
  fi

  do_test $filename $should_pass "-s nameresolution" "$stdlib2"
done

for filename in `find ${PUB_FOLDER}/assignment_testcases/a3 -name "*.java" -type f | grep "$file_name_test" | sort`; do
  should_pass=true;
  if [[ $(basename $filename) == Je* ]]; then
    should_pass=false;
  fi

  # TODO:
done

for filename in `find ${PUB_FOLDER}/assignment_testcases/a4 -name "*.java" -type f | grep "$file_name_test" | sort`; do
  should_pass=true;
  if [[ $(basename $filename) == Je* ]]; then
    should_pass=false;
  fi

  # TODO:
done

for filename in `find ${PUB_FOLDER}/assignment_testcases/a5 -name "*.java" -type f | grep "$file_name_test" | sort`; do
  should_pass=true;
  if [[ $(basename $filename) == Je* ]]; then
    should_pass=false;
  fi

  # TODO:
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
