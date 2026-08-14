const fs = require("fs");
const path = require("path");

const sourceDir = path.join(__dirname, "..", "src", "data");
const targetDir = path.join(__dirname, "..", "lib", "data");

if (!fs.existsSync(sourceDir)) {
  process.exit(0);
}

fs.mkdirSync(targetDir, {recursive: true});
for (const fileName of fs.readdirSync(sourceDir)) {
  if (fileName.endsWith(".json")) {
    fs.copyFileSync(path.join(sourceDir, fileName), path.join(targetDir, fileName));
  }
}
