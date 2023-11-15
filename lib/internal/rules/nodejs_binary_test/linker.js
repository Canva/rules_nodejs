"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || function (mod) {
    if (mod && mod.__esModule) return mod;
    var result = {};
    if (mod != null) for (var k in mod) if (k !== "default" && Object.prototype.hasOwnProperty.call(mod, k)) __createBinding(result, mod, k);
    __setModuleDefault(result, mod);
    return result;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.tryCreateSymlink = exports.getProposedSymlinks = exports.inferRunfilesDirFromPath = void 0;
const fs = __importStar(require("fs"));
const path = __importStar(require("path"));
// Run Bazel with --define=VERBOSE_LOGS=1 to enable this logging
const VERBOSE_LOGS = !!process.env['VERBOSE_LOGS'];
function log(...m) {
    if (VERBOSE_LOGS) {
        console.error(loggingPrefix, ...m);
    }
}
function fatal(context, errors) {
    console.error(loggingPrefix, 'Error(s) were reported.');
    console.error(loggingPrefix, 'Context:', context);
    for (const error of errors) {
        console.error(error);
    }
    console.error(loggingPrefix, 'Exiting');
    process.exit(1);
}
// NOTE Trailing '/' not included in matcher to cover all scenarios (e.g. RUNFILES_DIR environment variable)
const runfilesPathMatcher = '.runfiles';
const nodeModulesDir = 'node_modules';
const loggingPrefix = '[node_modules-linker]';
/**
 * Infers a runfiles directory from the given path, throwing on failure.
 * @param maybeRunfilesSource Path to inspect.
 */
function inferRunfilesDirFromPath(maybeRunfilesSource) {
    while (maybeRunfilesSource !== '/') {
        if (maybeRunfilesSource.endsWith(runfilesPathMatcher)) {
            return (maybeRunfilesSource + '/');
        }
        maybeRunfilesSource = path.dirname(maybeRunfilesSource);
    }
    throw new Error('Path does not contain a runfiles parent directory.');
}
exports.inferRunfilesDirFromPath = inferRunfilesDirFromPath;
/**
 * Gets the symlinks required to satisfy `node_modules` linking requirements.
 * @param modulesManifest Modules manifest to read `node_modules` roots from.
 * @param runfilesDirPath Runfiles directory symlinks should operate within.
 */
function getProposedSymlinks(modulesManifest, runfilesDirPath) {
    const symlinks = [];
    let relativeMountParent;
    for (relativeMountParent in modulesManifest.roots) {
        const repositoryName = modulesManifest.roots[relativeMountParent];
        const filePath = path.join(runfilesDirPath, modulesManifest.workspace, relativeMountParent, nodeModulesDir);
        const targetPath = path.join(runfilesDirPath, repositoryName, nodeModulesDir);
        symlinks.push([filePath, targetPath]);
    }
    return symlinks;
}
exports.getProposedSymlinks = getProposedSymlinks;
/**
 * @todo Replace with `error.cause` once on NodeJS >=16.9
 */
function ensureErrorInstance(err) {
    return err instanceof Error
        ? err
        : new Error(`Non-error thrown, value was "${err ?? 'NULL_OR_UNDEFINED'}"`);
}
function tryRun(func) {
    try {
        return func();
    }
    catch (err) {
        return ensureErrorInstance(err);
    }
}
function definedOrThrow(value, throwReason) {
    if (value == null) {
        throw new Error(throwReason);
    }
    return value;
}
/**
 * Creates symlink using a "try-else-check" approach to safeguard against concurrent creation.
 * On failure the (assumed to exist) symlink is inspected, an error is thrown if the target path
 * differs.
 */
function tryCreateSymlink(filePath, targetPath) {
    log(`attempting to create symlink "${filePath}" -> "${targetPath}"`);
    // Ensure parent directories exist, e.g. for @renderer_node_modules//rollup/bin:rollup
    fs.mkdirSync(path.join(filePath, '..'), { recursive: true });
    const symlinkResult = tryRun(() => fs.symlinkSync(targetPath, filePath));
    if (symlinkResult instanceof Error) {
        // Attempt failed, link likely already exists
        const readlinkResult = tryRun(() => fs.readlinkSync(filePath));
        if (readlinkResult instanceof Error) {
            // Very bad state, time to abort
            fatal('symlink creation', [symlinkResult, readlinkResult]);
        }
        // Ensure symlink target matches requirements, or bail
        if (readlinkResult !== targetPath) {
            throw new Error(`Invalid symlink target path "${readlinkResult}" detected, wanted "${targetPath}" for symlink at "${filePath}"`);
        }
        log('symlink already exists');
    }
}
exports.tryCreateSymlink = tryCreateSymlink;
const removeNulls = (value) => value != null;
function main() {
    log('Linking started');
    // Collect potential runfiles dir sources
    // Sometimes cwd is under runfiles
    const cwd = process.cwd();
    log('cwd:', cwd);
    // Runfiles environment variables are the preferred reference point, but can fail
    log('RUNFILES_DIR environment variable:', process.env.RUNFILES_DIR ?? '(unset)');
    log('RUNFILES environment variable:', process.env.RUNFILES ?? '(unset)');
    const envRunfilesCanidates = [process.env.RUNFILES_DIR, process.env.RUNFILES]
        .filter(removeNulls)
        .map(runfilesDir => {
        const adjustedRunfilesDir = fs.realpathSync(runfilesDir);
        if (runfilesDir !== adjustedRunfilesDir) {
            log(`Symlink dereferenced from runfiles path. Was "${runfilesDir}" now "${adjustedRunfilesDir}"`);
            return adjustedRunfilesDir;
        }
        return runfilesDir;
    });
    // Infer runfiles dir
    const runfilesDirPath = (() => {
        for (const maybeRunfilesSource of [...envRunfilesCanidates, cwd]) {
            try {
                log(`Attempting to infer runfiles directory from "${maybeRunfilesSource}"`);
                return inferRunfilesDirFromPath(maybeRunfilesSource);
            }
            catch (err) {
                log(`Could not resolve runfiles directory from "${maybeRunfilesSource}"`, ensureErrorInstance(err).message);
            }
        }
        throw new Error('Could not resolve runfiles directory from any data sources.');
    })();
    log('Resolved runfiles path:', runfilesDirPath);
    // Get required links from modules manifest
    const modulesManifestPath = definedOrThrow(process.argv[2], 'argv[2] is required to locate modules manifest but is missing.');
    log('Modules manifest path:', modulesManifestPath);
    const modulesManifestContent = fs.readFileSync(modulesManifestPath, 'utf-8');
    const modulesManifest = JSON.parse(modulesManifestContent);
    log('Modules manifest contents:', JSON.stringify(modulesManifest, null, 2));
    // Create links
    log('Inferring symlink paths...');
    const symlinks = getProposedSymlinks(modulesManifest, runfilesDirPath);
    for (const [filePath, targetPath] of symlinks) {
        tryCreateSymlink(filePath, targetPath);
    }
    // RBE HACK Advertise links
    log('Saving symlink paths...');
    if (!process.env.NM_SYMLINKS) {
        throw new Error();
    }
    fs.writeFileSync(process.env.NM_SYMLINKS, JSON.stringify(symlinks), 'utf-8');
    log('Linking finished');
}
if (require.main === module) {
    try {
        main();
    }
    catch (err) {
        fatal('unhandled exception', [ensureErrorInstance(err)]);
    }
}
