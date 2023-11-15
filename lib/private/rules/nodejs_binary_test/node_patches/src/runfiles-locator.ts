import * as fs from 'fs';
import * as path from 'path';

/** Runfiles directory path. e.g. `/__output_base__/execroot/com_canva_canva/bazel-out/___/bin/___/___.runfiles/web_node_modules/node_modules` */
export type RunfilesDirPath = string & { __RunfilesDirPath: never };

// NOTE Trailing '/' not included in matcher to cover all scenarios (e.g. RUNFILES_DIR environment variable)
const runfilesPathMatcher = '.runfiles';

/**
 * Infers a runfiles directory from the given path, throwing on failure.
 * @param maybeRunfilesSource Path to inspect.
 */
function inferRunfilesDirFromPath(maybeRunfilesSource: string): RunfilesDirPath {
  while (maybeRunfilesSource !== '/') {
    if (maybeRunfilesSource.endsWith(runfilesPathMatcher)) {
      return (maybeRunfilesSource + '/') as RunfilesDirPath;
    }

    maybeRunfilesSource = path.dirname(maybeRunfilesSource);
  }

  throw new Error('Path does not contain a runfiles parent directory.');
}

const removeNulls = <S>(value: S | undefined): value is S => value != null;

export function runfilesLocator(): RunfilesDirPath {
  // Sometimes cwd is under runfiles
  const cwd = process.cwd();

  // Runfiles environment variables are the preferred reference point, but can fail
  const envRunfilesCanidates = [process.env.RUNFILES_DIR, process.env.RUNFILES]
    .filter(removeNulls)
    .map(runfilesDir => {
      const adjustedRunfilesDir = fs.realpathSync(runfilesDir);
      if (runfilesDir !== adjustedRunfilesDir) {
        return adjustedRunfilesDir;
      }
      return runfilesDir;
    });

  // Infer runfiles dir
  for (const maybeRunfilesSource of [...envRunfilesCanidates, cwd]) {
    try {
      return inferRunfilesDirFromPath(maybeRunfilesSource);
    } catch (err) {
      // na-da
    }
  }
  throw new Error('Could not resolve runfiles directory from any data sources.');
}

/**
 * Helper to locate bundle (`node_patches.js`) under runfiles.
 * Implementation is depth sensitive, if bundle is moved this needs to be updated.
 */
export function resolveBundleUnderRunfiles(bundlePath: string, runfilesPath: RunfilesDirPath) {
  // Get external repos path
  // /__output-base__/external/__external-repo__/internal/node/node_patches.js
  // -> /__output-base__/external/
  const externalReposPath = path.join(bundlePath, '../../../../');

  // Get bundle path relative to /external/
  // /__output-base__/external/__external-repo__/internal/node/node_patches.js
  // - /__output-base__/external/
  // -> __external-repo__/internal/node/node_patches.js
  const bundleRelativeToRunfiles = path.relative(externalReposPath, bundlePath);

  // Produce path under runfiles
  // /__output-base__/execroot/__workspace-name__/bazel-out/__output-config__/bin/foo.runfiles/
  // + __external-repo__/internal/node/node_patches.js
  // -> /__output-base__/execroot/__workspace-name__/bazel-out/__output-config__/bin/foo.runfiles/__external-repo__/internal/node/node_patches.js
  return path.join(runfilesPath, bundleRelativeToRunfiles);
}
