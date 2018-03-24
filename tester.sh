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

finish() {
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
}

trap finish EXIT

do_test() {
  files="$1"
  should_pass=$2
  args=$3
  stdlib="$4"

  if [[ $files != *"$file_name_test"* ]]; then
    return
  fi

  ./joosc $args $files $stdlib >/dev/null 2>/dev/null
  result=$?
  description=""

  if [[ $result = 42 && $should_pass = true ]]; then
    description="== ${RED}FAIL${NC}: ${files}"
    bad_fail=$((bad_fail + 1))
    echo "== ${RED}FAIL${NC}: ./joosc $args -v $files $stdlib" >> $failed_test_descr_file
  elif [[ $result = 0 && $should_pass = true ]]; then
    description="== ${GREEN}PASS${NC}: ${files}"
    correct_pass=$((correct_pass + 1))
  elif [[ $result = 42 && $should_pass = false ]]; then
    description="== ${GREEN}FAIL${NC}: ${files}"
    correct_fail=$((correct_fail + 1))
  elif [[ $result = 0  && $should_pass = false ]]; then
    description="== ${RED}PASS${NC}: ${files}"
    bad_pass=$((bad_pass + 1))
    echo "== ${RED}PASS${NC}: ./joosc $args -v $files $stdlib" >> $failed_test_descr_file
  else
    description="== ${RED}EROR${NC}: ${files}"
    errors=$((errors + 1))
    echo "== ${RED}EROR${NC}: ./joosc $args -v $files $stdlib" >> $failed_test_descr_file
  fi

  echo $description
}

# ----------------------------------------------------------------------------
# Run against test files scraped from
# https://www.student.cs.uwaterloo.ca/~cs444/joos.html
# ----------------------------------------------------------------------------

PASS_FILES=$(find ${TEST_FOLDER}/parser/valid -type f | sort)
FAIL_FILES=$(find ${TEST_FOLDER}/parser/bad -type f | sort)

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

for filename in `find ${PUB_FOLDER}/assignment_testcases/a1 -name "*.java" -type f | sort`; do
  should_pass=true;
  # I believe "Je" stands for Joos Error
  if [[ $(basename $filename) == Je* ]]; then
    should_pass=false;
  fi

  do_test $filename $should_pass "-s weed"
done

for filename in `find ${PUB_FOLDER}/assignment_testcases/a2 -depth 1 | sort`; do
  should_pass=true;
  if [[ $(basename $filename) == Je* ]]; then
    should_pass=false;
  fi

  if [[ -f $filename && $filename == *.java ]]; then
    do_test $filename $should_pass "-s nameresolution" "$stdlib2"
    elif [[ -d $filename ]]; then
    files=$(find ${filename} -name "*.java" -type f -exec echo -n '{} ' \;)
    do_test "$files" $should_pass "-s nameresolution" "$stdlib2"
  fi
done

for filename in `find ${PUB_FOLDER}/assignment_testcases/a3 -depth 1 | sort`; do
  should_pass=true;
  if [[ $(basename $filename) == Je* ]]; then
    should_pass=false;
  fi

  if [[ -f $filename && $filename == *.java ]]; then
    do_test $filename $should_pass "-s typecheck" "$stdlib3"
    elif [[ -d $filename ]]; then
    files=$(find ${filename} -name "*.java" -type f -exec echo -n '{} ' \;)
    do_test "$files" $should_pass "-s typecheck" "$stdlib3"
  fi
done

for filename in `find ${PUB_FOLDER}/assignment_testcases/a4 -depth 1 | sort`; do
  should_pass=true;
  if [[ $(basename $filename) == Je* ]]; then
    should_pass=false;
  fi

  if [[ -f $filename && $filename == *.java ]]; then
    do_test $filename $should_pass "-s staticanalysis" "$stdlib4"
    elif [[ -d $filename ]]; then
    files=$(find ${filename} -name "*.java" -type f -exec echo -n '{} ' \;)
    do_test "$files" $should_pass "-s staticanalysis" "$stdlib4"
  fi
done

for filename in `find ${PUB_FOLDER}/assignment_testcases/a5 -name "*.java" -type f -depth 1 | sort`; do
  should_pass=true;
  if [[ $(basename $filename) == Je* ]]; then
    should_pass=false;
  fi

  if [[ -f $filename && $filename == *.java ]]; then
    do_test $filename $should_pass "-s all" "$stdlib5"
    elif [[ -d $filename ]]; then
    files=$(find ${filename} -name "*.java" -type f -exec echo -n '{} ' \;)
    do_test "$files" $should_pass "-s all" "$stdlib5"
  fi
done
