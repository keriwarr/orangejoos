# Joos program scraper

On the [Joos language][joos] page there is a table listing what Java 1.3 features Joos1W supports. Each feature also has a small program that excercises the syntax.

This tool scrapes the sample programs from the page, groups them, and then creates test files.

## Scraping the webpage

The Javascript in [tests_scraper.js] can be run on the [Joos][joos] page
to get a list of the test cases. It will print the JSON result, and also
copy it to the clipboard. The copied output can be passed into the
Python script [create_tests.py] python script to create the test files,
e.g. `python3 tools/joos_scraper/create_tests.py test/parser < jsoutput.txt `.

[tests_scraper.js]: /tests_scraper.js
[create_tests.py]: /create_tests.py
[joos]: https://www.student.cs.uwaterloo.ca/~cs444/joos.html
