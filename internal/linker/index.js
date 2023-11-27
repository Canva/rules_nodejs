/* THIS FILE GENERATED FROM .ts; see BUILD.bazel */ /* clang-format off */"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.tryCreateSymlink = exports.getProposedSymlinks = exports.inferRunfilesDirFromPath = void 0;
const fs = require("fs");
const path = require("path");
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
const runfilesPathMatcher = '.runfiles';
const nodeModulesDir = 'node_modules';
const loggingPrefix = '[node_modules-linker]';
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
function getProposedSymlinks(modulesManifest, runfilesDirPath) {
    const symlinks = [];
    let relativeMountParent;
    for (relativeMountParent in modulesManifest.roots) {
        const repositoryName = modulesManifest.roots[relativeMountParent];
        const filePath = path.join(runfilesDirPath, modulesManifest.workspace, relativeMountParent, nodeModulesDir);
        const targetPath = path.join(runfilesDirPath, repositoryName, nodeModulesDir);
        symlinks.push({ filePath, targetPath });
    }
    return symlinks;
}
exports.getProposedSymlinks = getProposedSymlinks;
function ensureErrorInstance(err) {
    return err instanceof Error
        ? err
        : new Error(`Non-error thrown, value was "${err !== null && err !== void 0 ? err : 'NULL_OR_UNDEFINED'}"`);
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
function tryCreateSymlink(filePath, targetPath) {
    log(`attempting to create symlink "${filePath}" -> "${targetPath}"`);
    fs.mkdirSync(path.join(filePath, '..'), { recursive: true });
    const symlinkResult = tryRun(() => fs.symlinkSync(targetPath, filePath));
    if (symlinkResult instanceof Error) {
        const readlinkResult = tryRun(() => fs.readlinkSync(filePath));
        if (readlinkResult instanceof Error) {
            fatal('symlink creation', [symlinkResult, readlinkResult]);
        }
        if (readlinkResult !== targetPath) {
            throw new Error(`Invalid symlink target path "${readlinkResult}" detected, wanted "${targetPath}" for symlink at "${filePath}"`);
        }
        log('symlink already exists');
    }
}
exports.tryCreateSymlink = tryCreateSymlink;
const removeNulls = (value) => value != null;
function main() {
    var _a, _b;
    log('Linking started');
    const cwd = process.cwd();
    log('cwd:', cwd);
    log('RUNFILES_DIR environment variable:', (_a = process.env.RUNFILES_DIR) !== null && _a !== void 0 ? _a : '(unset)');
    log('RUNFILES environment variable:', (_b = process.env.RUNFILES) !== null && _b !== void 0 ? _b : '(unset)');
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
    const modulesManifestPath = definedOrThrow(process.argv[2], 'argv[2] is required to locate modules manifest but is missing.');
    log('Modules manifest path:', modulesManifestPath);
    const modulesManifestContent = fs.readFileSync(modulesManifestPath, 'utf-8');
    const modulesManifest = JSON.parse(modulesManifestContent);
    log('Modules manifest contents:', JSON.stringify(modulesManifest, null, 2));
    log('Inferring symlink paths...');
    const symlinks = getProposedSymlinks(modulesManifest, runfilesDirPath);
    for (const { filePath, targetPath } of symlinks) {
        tryCreateSymlink(filePath, targetPath);
    }
    log('Saving symlink paths...');
    const nmSymlinks = definedOrThrow(process.env.NM_SYMLINKS, 'expected $NM_SYMLINKS to be set in the environment');
    fs.writeFileSync(nmSymlinks, JSON.stringify(symlinks), 'utf-8');
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
