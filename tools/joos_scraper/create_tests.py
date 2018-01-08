"""
create_tests will parse the output from tests_scraper.js and write the
programs into test case directories.
"""

import sys
import os
import json


def filenameify(test):
  """
  Generates the file path for a given test.
  """

  def pathify(name):
    """
    Cleans a name to be a proper path.
    """
    return name.lower().replace(" ", "_").replace("/", "-")

  filename = ""
  if test["supported"] == "Y":
    filename += "valid/"
  else:
    filename += "bad/"

  filename += pathify(test["category"]) + "/"
  filename += pathify(test["featureName"]) + ".java"
  return filename



if __name__ == "__main__":
  if len(sys.argv) != 2:
    print("""Usage: pass the folder to write tests to.

    For example,

        python3 {filename} test/parser""".format(filename=sys.argv[0]))
    sys.exit(1)

  print("Reading JSON from stdin...")

  # Read the JSON results retrieved with the scraping console script.
  files = None
  try:
    files = json.load(sys.stdin)
  except:
    print("Could not parse JSON from stdin")
    sys.exit(1)

  for test in files:
    # Generate the file handle for a test case.
    filename = filenameify(test)
    # Prefix all paths with the path provided as a CLI arg.
    filename = os.path.join(sys.argv[1], filename)
    # Attempt to make directories on path if they do not exist.
    os.makedirs(os.path.dirname(filename), exist_ok=True)
    # Write the contents of the source file.
    with open(filename, "w") as f:
      f.write(test["contents"])

  print("Done!")
