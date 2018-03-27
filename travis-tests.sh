#!/bin/bash

set -v

./tester.sh
mv failed_tests.tmp failed_tests_pr.tmp
git checkout $(git ls-remote origin | grep "refs/heads/master" | awk '{ print $1 }')
./tester.sh
diff failed_tests.tmp failed_tests_pr.tmp | grep "✗"
if [[ $? = 0 ]]; then
  exit 1;
fi
exit 0;
