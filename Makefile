
CRYSTAL_SRCS := $(find src -name '*.cr')
JLALR_SRCS := $(find tools/jlalr -name '*.java')

orangejoos: $(CRYSTAL_SRCS)
	crystal build ./src/orangejoos.cr

jlalr1: $(JLALR_SRCS)
	javac ./tools/jlalr/Jlalr1.java
	java -cp ./tools/ jlalr.Jlalr1

.PHONY: clean
clean:
	find . -name '*.class' | xargs -I{} rm {}
	rm -f joosc.jar
	rm -f orangejoos orangejoos.dwarf