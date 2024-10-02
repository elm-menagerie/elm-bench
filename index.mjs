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
Benchmarking function `remove`.
  ./listRemoveOld   ████████████████████   351 ns   baseline
  ./listRemoveNew   ██████████████         246 ns   30% faster

TODO: eject into elm-benchmark code (receive an arg saying where to put it, and use that instead of the temp dir, and don't delete that afterwards)
TODO: check the Debug.toString representation of the versions is the same, and show a warning if it's not
TODO: JSON report mode
*/

import { parseArgs, promisify } from "node:util";
import fs from "node:fs/promises";
import path from "node:path";
import os from "node:os";
import * as childProcess from "node:child_process";

import semver from "semver";

const capitalize = (str) => str.charAt(0).toUpperCase() + str.slice(1);

const green = (str) => `\x1b[32m${str}\x1b[0m`;

// 1. Parse arguments

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

console.log(`Benchmarking function \`${functionName}\`.`);

// resolve relative path (remove ./ from the string)
const versionDirs = versions.map((version) => path.relative(".", version));

// 2. Prepare the JS+Elm program

// 2.1 Copy `template/` to a temporary directory
const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), "elm-bench-"));
const templateDir = path.join(import.meta.dirname, "template");
await fs.cp(templateDir, tempDir, { recursive: true });

const benchmarksElmPath = path.join(tempDir, "src", "Benchmarks.elm");
let benchmarksElmContent = await fs.readFile(benchmarksElmPath, "utf-8");

// 2.2 Replace `{{FUNCTION_NAME}}` with the function name
benchmarksElmContent = benchmarksElmContent.replace(
  "{{FUNCTION_NAME}}",
  functionName
);

// 2.3 Replace `{{VERSIONS}}` with the versions
const versionsCode = `[ ${versionDirs
  .map(
    (version) =>
      `( "${version}", Version.${capitalize(version)}.${functionName} )`
  )
  .join("\n        , ")}
        ]`;

benchmarksElmContent = benchmarksElmContent.replace(
  "{{VERSIONS}}",
  versionsCode
);

// 2.4 Replace `{{ARGS}}` with the arguments
const argsCode = args.map((_, i) => `arg${i}`).join(" ");

benchmarksElmContent = benchmarksElmContent.replace("{{ARGS}}", argsCode);

// 2.5 Replace `{{IMPORTS}}` with the imports
const importsCode = versionDirs
  .map((version) => `import Version.${capitalize(version)}`)
  .join("\n");

benchmarksElmContent = benchmarksElmContent.replace("{{IMPORTS}}", importsCode);

// 2.6 Replace `{{ARG_DEFS}}` with the argument definitions
const argDefsCode = args.map((arg, i) => `arg${i} =\n    ${arg}`).join("\n\n\n");

benchmarksElmContent = benchmarksElmContent.replace(
  "{{ARG_DEFS}}",
  argDefsCode
);

await fs.writeFile(benchmarksElmPath, benchmarksElmContent, "utf-8");

// 2.7 Copy the versions' code into src/Versions, change the module declaration and rename the Main module
/*
Before:

- listRemoveOld/src/WhateverElse.elm
- listRemoveOld/src/Main.elm
- listRemoveOld/elm.json

- listRemoveNew/src/WhateverElse.elm
- listRemoveNew/src/Main.elm
- listRemoveNew/elm.json

After:

- ${tempDir}/src/Version/ListRemoveOld/WhateverElse.elm (with changed module name and imports)
- ${tempDir}/src/Version/ListRemoveOld.elm              (with changed module name and imports)
- ${tempDir}/src/Version/ListRemoveNew/WhateverElse.elm (with changed module name and imports)
- ${tempDir}/src/Version/ListRemoveNew.elm              (with changed module name and imports)
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

for (const version of versionDirs) {
  const versionCapitalized = capitalize(version);
  const srcDir = path.join(version, "src");
  const versionDir = path.join(tempDir, "src", "Version");
  const destDir = path.join(tempDir, "src", "Version", versionCapitalized);

  // Create destination directory
  await fs.mkdir(destDir, { recursive: true });

  // Copy and modify all Elm files
  const elmFiles = await findElmFiles(srcDir);

  for (const file of elmFiles) {
    const destPath = file.endsWith("Main.elm")
      ? path.join(versionDir, `${versionCapitalized}.elm`)
      : file;

    let content = await fs.readFile(file, "utf-8");

    // Modify module declaration
    content = content.replace(
      /^module\s+(\w+)(?:\s+exposing\s*\(([\s\S]*?)\))?/m,
      `module Version.${versionCapitalized}${file.endsWith("Main.elm") ? "" : `.${path.basename(file, ".elm")}`
      } exposing ($2)`
    );

    // Modify imports
    content = content.replace(
      /^import\s+(\w+(?:\.\w+)*)/gm,
      (match, module) => {
        if (
          module !== "Main" &&
          elmFiles.some((file) => file === `${module}.elm`)
        ) {
          return `import Version.${versionCapitalized}.${module}`;
        }
        return match;
      }
    );

    await fs.writeFile(destPath, content, "utf-8");
  }
}

// Combine elm.json dependencies
const combinedDependencies = { direct: {}, indirect: {} };
for (const version of versionDirs) {
  const elmJsonPath = path.join(version, "elm.json");
  const elmJson = JSON.parse(await fs.readFile(elmJsonPath, "utf-8"));

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

// Update the temporary project's elm.json
const tempElmJsonPath = path.join(tempDir, "elm.json");
const tempElmJson = JSON.parse(await fs.readFile(tempElmJsonPath, "utf-8"));

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

// 3. Run the program and collect the results

// 3.1 Run elm make on the generated Elm code
const exec = promisify(childProcess.exec);

const elmMakeCommand = `elm make src/Benchmarks.elm --optimize --output elm.js`;
try {
  const { stderr } = await exec(elmMakeCommand, { cwd: tempDir, encoding: "utf-8" });
  if (stderr && stderr.length > 0) {
    if (stderr) {
      console.error("Elm make errors:");
      console.error(stderr);
    }
  }
} catch (error) {
  console.error("Error running elm make:", error);
  throw error;
}

// 3.2 Run the generated program

// Run the generated program
async function runGeneratedProgram() {
  const nodeCommand = 'node main.js';
  try {
    const { stdout, stderr } = await exec(nodeCommand, { cwd: tempDir, encoding: "utf-8" });
    if (stderr && stderr.length > 0) {
      console.error("Node execution errors:");
      console.error(stderr);
    }

    const results = JSON.parse(stdout);
    return results;
  } catch (error) {
    console.error("Error running the generated program:", error);
    throw error;
  }
}

const results = await runGeneratedProgram();

// 4. Print the results

/* Example of `results`:

  {
    "results": [
      { "name": [ "remove", "listRemoveOld" ], "nsPerRun": 309.43958596194926 },
      { "name": [ "remove", "listRemoveNew" ], "nsPerRun": 244.48914830045732 }
    ],
    "warning": null
  }

*/

// 4. Print the results

const baseline = results.results[0].nsPerRun;
const maxNameLength = Math.max(...versions.map((v) => v.length));
const maxBarLength = 20;

const fastestIndex = results.results.reduce((minIndex, result, currentIndex, array) => {
  return result.nsPerRun < array[minIndex].nsPerRun ? currentIndex : minIndex;
}, 0);

results.results.forEach((result, index) => {
  const { nsPerRun } = result;
  const version = versions[index];
  const barLength = Math.round((nsPerRun / baseline) * maxBarLength);
  const bar = '█'.repeat(barLength);
  const nsRounded = Math.round(nsPerRun);
  const padding = ' '.repeat(maxNameLength - version.length);
  const isFastest = index === fastestIndex;

  let comparison = '';
  if (index === 0) {
    comparison = 'baseline';
  } else {
    const percentDiff = Math.round((nsPerRun / baseline - 1) * 100);
    if (percentDiff > 0) {
      comparison = `${percentDiff}% slower`;
    } else if (percentDiff < 0) {
      comparison = `${Math.abs(percentDiff)}% faster`;
    } else {
      comparison = 'same speed';
    }
  }

  const versionC = isFastest ? green(version) : version;
  const comparisonC = isFastest ? green(comparison) : comparison;

  console.log(`  ${versionC}${padding}   ${bar.padEnd(maxBarLength)}   ${nsRounded} ns   ${comparisonC}`);
});

if (results.warning) {
  console.warn("Warning:", results.warning);
}

// 5. Remove the temporary files

await fs.rm(tempDir, { recursive: true });