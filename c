#!/bin/bash
ASSN=$2
if [ $1 == 'true' ]; then
  STDLIB=$(find ./pub/stdlib/$ASSN.0/java -type f -name '*.java')
else
  FLAGS="--no-stdlib"
fi

SRCS=$(find ./pub/assignment_testcases/a$ASSN/ -type f -name '*.java' | grep ${3})
make ASSN=A$ASSN && ./joosc $STDLIB $SRCS -v $FLAGS
