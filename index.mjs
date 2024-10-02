/*
elm-bench
---------
A small CLI utility for easy benchmarking of Elm code.

Example usage:
  elm-bench -v ./listRemoveOld -v ./listRemoveNew remove 99 "List.range 0 1000"

Expects listRemoveOld and listRemoveNew to be directories containingElm
applications whose `src/Main.elm` exposes the `remove` function.
Each `remove` function should accept an Int and a List Int.
elm-bench will plug each `remove` function into an elm-benchmark program and
give you the results on the CLI:

$ elm-bench -v ./listRemoveOld -v ./listRemoveNew remove 99 "List.range 0 1000"
  ./listRemoveOld ████████   34 ns   baseline
  ./listRemoveNew ██          9 ns   73% faster

TODO: eject into elm-benchmark code (receive an arg saying where to put it, and use that instead of the temp dir, and don't delete that afterwards)
*/

import { parseArgs } from "node:util";
import fs from "node:fs/promises";
import path from "node:path";
import os from "node:os";
import semver from "semver";

const debug = process.env.DEBUG === "elm-bench";
const log = debug ? console.log : () => {};

const capitalize = (str) => str.charAt(0).toUpperCase() + str.slice(1);

// 1. Parse arguments
log("1");

const { values, positionals } = parseArgs({
  options: {
    version: {
      type: "string",
      short: "v",
      multiple: true,
    },
  },
  allowPositionals: true,
});

if (!("version" in values)) {
  console.error("No versions to benchmark");
  process.exit(1);
}

if (positionals.length < 1) {
  console.error("No function to benchmark");
  process.exit(1);
}

const versions = [...values.version];
const functionName = positionals[0];
const args = positionals.slice(1);

// 2. Prepare the JS+Elm program
log("2");

// 2.1 Copy `template/` to a temporary directory
log("2.1");
const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), "elm-bench-"));
const templateDir = path.join(import.meta.dirname, "template");
await fs.cp(templateDir, tempDir, { recursive: true });

const benchmarksElmPath = path.join(tempDir, "src", "Benchmarks.elm");
let benchmarksElmContent = await fs.readFile(benchmarksElmPath, "utf-8");

// 2.2 Replace `{{FUNCTION_NAME}}` with the function name
log("2.2");
benchmarksElmContent = benchmarksElmContent.replace(
  "{{FUNCTION_NAME}}",
  functionName
);

// 2.3 Replace `{{VERSIONS}}` with the versions
log("2.3");
const versionsCode = `[ ${versions
  .map(
    (version) =>
      `( "${version}", Version.${capitalize(version)}.${functionName} )`
  )
  .join(", ")} ]`;

benchmarksElmContent = benchmarksElmContent.replace(
  "{{VERSIONS}}",
  versionsCode
);

// 2.4 Replace `{{ARGS}}` with the arguments
log("2.4");
const argsCode = args.map((_, i) => `arg${i}`).join(" ");

benchmarksElmContent = benchmarksElmContent.replace("{{ARGS}}", argsCode);

// 2.5 Replace `{{IMPORTS}}` with the imports
log("2.5");
const importsCode = versions
  // TODO START HERE! remove the ./ from the version paths
  // DEBUG=elm-bench node index.mjs -v ./listRemoveOld -v ./listRemoveNew remove 42 "List.range 0 1000"
  .map((version) => `import Version.${capitalize(version)}`)
  .join("\n");

benchmarksElmContent = benchmarksElmContent.replace("{{IMPORTS}}", importsCode);

// 2.6 Replace `{{ARG_DEFS}}` with the argument definitions
log("2.6");
const argDefsCode = args.map((arg, i) => `arg${i} = ${arg}`).join("\n");

benchmarksElmContent = benchmarksElmContent.replace(
  "{{ARG_DEFS}}",
  argDefsCode
);

await fs.writeFile(benchmarksElmPath, benchmarksElmContent, "utf-8");

// 2.7 Copy the versions' code into src/Versions, change the module declaration and rename the Main module
log("2.7");
/*
Before:

- listRemoveOld/src/WhateverElse.elm
- listRemoveOld/src/Main.elm
- listRemoveOld/elm.json

- listRemoveNew/src/WhateverElse.elm
- listRemoveNew/src/Main.elm
- listRemoveNew/elm.json

After:

- ${tempDir}/src/Versions/ListRemoveOld/WhateverElse.elm (with changed module name and imports)
- ${tempDir}/src/Versions/ListRemoveOld.elm              (with changed module name and imports)
- ${tempDir}/src/Versions/ListRemoveNew/WhateverElse.elm (with changed module name and imports)
- ${tempDir}/src/Versions/ListRemoveNew.elm              (with changed module name and imports)
- ${tempDir}/elm.json (with combined dependencies of all versions)
*/

async function findElmFiles(dir) {
  const entries = await fs.readdir(dir, { withFileTypes: true });
  const files = await Promise.all(
    entries.map((entry) => {
      const res = path.resolve(dir, entry.name);
      return entry.isDirectory() ? findElmFiles(res) : res;
    })
  );
  return files.flat().filter((file) => file.endsWith(".elm"));
}

for (const version of versions) {
  log("2.7 version", version);
  const versionCapitalized = capitalize(version);
  const srcDir = path.join(version, "src");
  const versionsDir = path.join(tempDir, "src", "Versions");
  const destDir = path.join(tempDir, "src", "Versions", versionCapitalized);

  // Create destination directory
  log("2.7 dest", destDir);
  await fs.mkdir(destDir, { recursive: true });

  // Copy and modify all Elm files
  const elmFiles = await findElmFiles(srcDir);

  log("2.7 elm", elmFiles);

  for (const file of elmFiles) {
    const destPath = file.endsWith("Main.elm")
      ? path.join(versionsDir, `${versionCapitalized}.elm`)
      : file;

    let content = await fs.readFile(file, "utf-8");

    // Modify module declaration
    log("2.7 modify module");
    content = content.replace(
      /^module\s+(\w+)(?:\s+exposing\s*\(([\s\S]*?)\))?/m,
      `module Versions.${versionCapitalized}${
        file.endsWith("Main.elm") ? "" : `.${path.basename(file, ".elm")}`
      } exposing ($2)`
    );

    // Modify imports
    log("2.7 modify imports");
    content = content.replace(
      /^import\s+(\w+(?:\.\w+)*)/gm,
      (match, module) => {
        if (
          module !== "Main" &&
          elmFiles.some((file) => file === `${module}.elm`)
        ) {
          return `import Versions.${versionCapitalized}.${module}`;
        }
        return match;
      }
    );

    log("2.7 write");
    await fs.writeFile(destPath, content, "utf-8");
  }
}

// Combine elm.json dependencies
log("2.7 combine elm json");
const combinedDependencies = { direct: {}, indirect: {} };
for (const version of versions) {
  const elmJsonPath = path.join(version, "elm.json");
  const elmJson = JSON.parse(await fs.readFile(elmJsonPath, "utf-8"));
  log("2.7 single", elmJson);

  for (const depType of ["direct", "indirect"]) {
    for (const [pkg, ver] of Object.entries(elmJson.dependencies[depType])) {
      if (
        !combinedDependencies[depType][pkg] ||
        semver.gt(ver, combinedDependencies[depType][pkg])
      ) {
        combinedDependencies[depType][pkg] = ver;
      }
    }
  }
}
log("2.7 combined", combinedDependencies);

// Update the temporary project's elm.json
const tempElmJsonPath = path.join(tempDir, "elm.json");
const tempElmJson = JSON.parse(await fs.readFile(tempElmJsonPath, "utf-8"));
log("2.7 temp", tempElmJson);
// Merge dependencies, preferring direct over indirect and higher semver
for (const depType of ["direct", "indirect"]) {
  tempElmJson.dependencies[depType] = {
    ...tempElmJson.dependencies[depType],
    ...Object.fromEntries(
      Object.entries(combinedDependencies[depType]).map(([pkg, ver]) => {
        const existingVer = tempElmJson.dependencies[depType][pkg];
        const directVer = tempElmJson.dependencies.direct[pkg];

        if (directVer) {
          // If it exists in direct dependencies, use that version
          return [pkg, directVer];
        } else if (existingVer) {
          // If it exists in the same dependency type, use the higher semver
          return [pkg, semver.gt(ver, existingVer) ? ver : existingVer];
        } else {
          // If it doesn't exist in tempElmJson, add it
          return [pkg, ver];
        }
      })
    ),
  };
}

// Move any remaining indirect dependencies to direct if they exist in both
for (const [pkg, _] of Object.entries(tempElmJson.dependencies.indirect)) {
  if (pkg in tempElmJson.dependencies.direct) {
    delete tempElmJson.dependencies.indirect[pkg];
  }
}
await fs.writeFile(
  tempElmJsonPath,
  JSON.stringify(tempElmJson, null, 4),
  "utf-8"
);
log("2.7 written", tempElmJson);

// 3. Run the program and collect the results

// 4. Print the results

// 5. Remove the temporary files
