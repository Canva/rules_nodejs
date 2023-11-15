/**
 * @fileoverview This script reads the package.json file
 * of a yarn_install or npm_install rule and performs steps
 * that may be required before running yarn or npm such as
 * clearing the yarn cache for `file://` URIs to work-around
 * https://github.com/yarnpkg/yarn/issues/2165.
 */
'use strict';

const fs = require('fs');
const child_process = require('child_process');

function log_verbose(...m: string[]) {
  if (!!process.env['VERBOSE_LOGS']) console.error('[pre_process_package_json.js]', ...m);
}

const args = process.argv.slice(2);
const packageJson = args[0];
const packageManager = args[1];

if (require.main === module) {
  main();
}

/**
 * Main entrypoint.
 */
function main() {
  const isYarn = (packageManager === 'yarn');

  const pkg = JSON.parse(fs.readFileSync(packageJson, {encoding: 'utf8'}));

  log_verbose(`pre-processing package.json`);

  if (isYarn) {
    // Work-around for https://github.com/yarnpkg/yarn/issues/2165
    // Note: there is no equivalent npm functionality to clean out individual packages
    // from the npm cache.
    clearYarnFilePathCaches(pkg);
  }
}

/**
 * Runs `yarn cache clean` for all packages that have `file://` URIs.
 * Work-around for https://github.com/yarnpkg/yarn/issues/2165.
 */
function clearYarnFilePathCaches(pkg: Record<string, any>) {
  const fileRegex = /^file\:\/\//i;
  const clearPackages: string[] = [];

  if (pkg.dependencies) {
    Object.keys(pkg.dependencies).forEach(p => {
      if (pkg.dependencies[p].match(fileRegex)) {
        clearPackages.push(p);
      }
    });
  }
  if (pkg.devDependencies) {
    Object.keys(pkg.devDependencies).forEach(p => {
      if (pkg.devDependencies[p].match(fileRegex)) {
        clearPackages.push(p);
      }
    });
  }
  if (pkg.optionalDependencies) {
    Object.keys(pkg.optionalDependencies).forEach(p => {
      if (pkg.optionalDependencies[p].match(fileRegex)) {
        clearPackages.push(p);
      }
    });
  }

  if (clearPackages.length) {
    log_verbose(`cleaning packages from yarn cache: ${clearPackages.join(' ')}`);
    for (const c of clearPackages) {
      child_process.execFileSync(
          'yarn', ['--mutex', 'network', 'cache', 'clean', c],
          {stdio: [process.stdin, process.stdout, process.stderr]});
    }
  }
}

module.exports = {main};
