
KOTLIN_SRC := $(wildcard src/**/*.kt)

default: joosc.jar

joosc.jar: $(KOTLIN_SRC)
	kotlinc src/orangejoos/main.kt -include-runtime -d joosc.jar
