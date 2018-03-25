#!/bin/bash
ASSN=$2
if [ $1 == 'true' ]; then
  STDLIB=$(find ./pub/stdlib/$ASSN.0/java -type f -name '*.java' -exec echo -n '{} ' \;)
else
  FLAGS="--no-stdlib"
fi

SRCS=$(find ./pub/assignment_testcases/a$ASSN -type f -name '*.java' | grep ${3})
make ASSN=A$ASSN && ./joosc $STDLIB $SRCS -v $FLAGS

PLATFORM=$(uname)
if [ $ASSN == "5" ]; then
  if [[ $PLATFORM == 'Darwin' ]]; then
    FILES=$(find output/*.s)
    for file in $FILES; do
      output_file="${file%.s}.o"
      nasm -O1 -f macho -F dwarf -g $file -o $output_file
    done
    ld -o output/main output/*.o
    ./output/main
    echo $?
  else
    FILES=$(find output/*.s)
    for file in $FILES; do
      output_file="${file%.s}.o"
      nasm -O1 -f elf -g -F dwarf $file -o $output_file
    done
    ld  -melf_i386 -o output/main output/*.o
    ./output/main
    echo $?
  fi
fi
