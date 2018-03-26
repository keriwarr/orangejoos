#!/bin/bash

set -v

./tester.sh
mv failed_tests.tmp failed_tests_pr.tmp
git checkout remotes/origin/master
./tester.sh
diff failed_tests.tmp failed_tests_pr.tmp | grep "✗"
if [[ $? = 0 ]]; then
  exit 1;
fi
exit 0;
