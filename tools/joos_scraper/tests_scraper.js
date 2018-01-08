// 
// Run this script on the Joos page to collect test cases. Further
// instructions can be found in README.md
//

// Get the feature table.
var table = $("table").children[0];
var category;
var features = [];

function httpGet(url) {
  var xmlHttp = new XMLHttpRequest();
  xmlHttp.open("GET", url, false /* async */);
  xmlHttp.send(null);
  return xmlHttp.responseText;
}

// Fetch the example source code pages and parse them into usable sources.
function getSourceCode(url) {
  // Get the source URL page.
  var result = httpGet(url);
  // Parse the source page, as it is an HTML page.
  var parser = new DOMParser();
  var doc = parser.parseFromString(result, "text/html");
  // Keep only the text. This drops highlighting and other aspects we want to ignore.
  return doc.body.innerText;
}

// Get all of the feature rows.
for (var i = 0; i < table.children.length; i++) {
  row = table.children[i];
  // When there is only one column in a row, the row is a category header.
  if (row.children.length == 1) {
    category = row.innerText;
    // Skip an additional row, which is another header row.
    i++;
    continue;
  }

  var supported = (row.children[3].innerText == "X") ? "Y" : "N";
  var sourceURL = row.children[0].children[0].href;
  var featureName = row.children[0].innerText;
  var contents = getSourceCode(sourceURL);
  features.push({
    category: category,
    featureName: featureName,
    sourceURL: sourceURL,
    contents: contents,
    supported: supported,
  });
}

// JSONify the results and copy them to the clipboard.
copy(JSON.stringify(features));
console.log("DONE");