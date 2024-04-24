'use strict';

var fs = require('fs');
var path = require('path');
var util = require('util');

function _interopNamespaceDefault(e) {
    var n = Object.create(null);
    if (e) {
        Object.keys(e).forEach(function (k) {
            if (k !== 'default') {
                var d = Object.getOwnPropertyDescriptor(e, k);
                Object.defineProperty(n, k, d.get ? d : {
                    enumerable: true,
                    get: function () { return e[k]; }
                });
            }
        });
    }
    n.default = e;
    return Object.freeze(n);
}

var fs__namespace = /*#__PURE__*/_interopNamespaceDefault(fs);
var path__namespace = /*#__PURE__*/_interopNamespaceDefault(path);
var util__namespace = /*#__PURE__*/_interopNamespaceDefault(util);

function patcher$1(fs = fs__namespace, roots) {
    fs = fs || fs__namespace;
    roots = roots || [];
    roots = roots.filter(root => fs.existsSync(root));
    if (!roots.length) {
        if (process.env.VERBOSE_LOGS) {
            console.error('fs patcher called without any valid root paths ' + __filename);
        }
        return;
    }
    const origRealpath = fs.realpath.bind(fs);
    const origRealpathNative = fs.realpath.native;
    const origLstat = fs.lstat.bind(fs);
    const origStat = fs.stat.bind(fs);
    const origStatSync = fs.statSync.bind(fs);
    const origReadlink = fs.readlink.bind(fs);
    const origLstatSync = fs.lstatSync.bind(fs);
    const origRealpathSync = fs.realpathSync.bind(fs);
    const origRealpathSyncNative = fs.realpathSync.native;
    const origReadlinkSync = fs.readlinkSync.bind(fs);
    const origReaddir = fs.readdir.bind(fs);
    const origReaddirSync = fs.readdirSync.bind(fs);
    const { isEscape } = escapeFunction(roots);
    const logged = {};
    fs.lstat = (...args) => {
        const ekey = new Error('').stack || '';
        if (!logged[ekey]) {
            logged[ekey] = true;
        }
        let cb = args.length > 1 ? args[args.length - 1] : undefined;
        // preserve error when calling function without required callback.
        if (cb) {
            cb = once(cb);
            args[args.length - 1] = (err, stats) => {
                if (err) {
                    return cb(err);
                }
                path__namespace.resolve(
                  // node 20.12 tightened the constraints and requires the input to be a string
                  String(args[0]),
                );
                if (!stats.isSymbolicLink()) {
                    return cb(null, stats);
                }
                return origReadlink(args[0], (err, str) => {
                    if (err) {
                        if (err.code === 'ENOENT') {
                            return cb(null, stats);
                        }
                        else if (err.code === 'EINVAL') {
                            // readlink only returns einval when the target is not a link.
                            // so if we found a link and it's no longer a link someone raced file system
                            // modifications. we return the error but a strong case could be made to return the
                            // original stat.
                            return cb(err);
                        }
                        else {
                            // some other file system related error.
                            return cb(err);
                        }
                    }
                    str = path__namespace.resolve(path__namespace.dirname(args[0]), str);
                    if (isEscape(str, args[0])) {
                        // if it's an out link we have to return the original stat.
                        return origStat(args[0], (err, plainStat) => {
                            if (err && err.code === 'ENOENT') {
                                // broken symlink. return link stats.
                                return cb(null, stats);
                            }
                            cb(err, plainStat);
                        });
                    }
                    // its a symlink and its inside of the root.
                    cb(null, stats);
                });
            };
        }
        origLstat(...args);
    };
    fs.realpath = (...args) => {
        let cb = args.length > 1 ? args[args.length - 1] : undefined;
        if (cb) {
            cb = once(cb);
            args[args.length - 1] = (err, str) => {
                if (err) {
                    return cb(err);
                }
                if (isEscape(str, args[0])) {
                    cb(null, path__namespace.resolve(args[0]));
                }
                else {
                    cb(null, str);
                }
            };
        }
        origRealpath(...args);
    };
    fs.realpath.native = (...args) => {
        let cb = args.length > 1 ? args[args.length - 1] : undefined;
        if (cb) {
            cb = once(cb);
            args[args.length - 1] = (err, str) => {
                if (err) {
                    return cb(err);
                }
                if (isEscape(str, args[0])) {
                    cb(null, path__namespace.resolve(args[0]));
                }
                else {
                    cb(null, str);
                }
            };
        }
        origRealpathNative(...args);
    };
    fs.readlink = (...args) => {
        let cb = args.length > 1 ? args[args.length - 1] : undefined;
        if (cb) {
            cb = once(cb);
            args[args.length - 1] = (err, str) => {
                args[0] = path__namespace.resolve(args[0]);
                if (str) {
                    str = path__namespace.resolve(path__namespace.dirname(args[0]), str);
                }
                if (err) {
                    return cb(err);
                }
                if (isEscape(str, args[0])) {
                    const e = new Error("EINVAL: invalid argument, readlink '" + args[0] + "'");
                    // tslint:disable-next-line:no-any
                    e.code = 'EINVAL';
                    // if its not supposed to be a link we have to trigger an EINVAL error.
                    return cb(e);
                }
                cb(null, str);
            };
        }
        origReadlink(...args);
    };
    fs.lstatSync = (...args) => {
        const stats = origLstatSync(...args);
        const linkPath = path__namespace.resolve(args[0]);
        if (!stats.isSymbolicLink()) {
            return stats;
        }
        let linkTarget;
        try {
            linkTarget = path__namespace.resolve(path__namespace.dirname(args[0]), origReadlinkSync(linkPath));
        }
        catch (e) {
            if (e.code === 'ENOENT') {
                return stats;
            }
            throw e;
        }
        if (isEscape(linkTarget, linkPath)) {
            try {
                return origStatSync(...args);
            }
            catch (e) {
                // enoent means we have a broken link.
                // broken links that escape are returned as lstat results
                if (e.code !== 'ENOENT') {
                    throw e;
                }
            }
        }
        return stats;
    };
    fs.realpathSync = (...args) => {
        const str = origRealpathSync(...args);
        if (isEscape(str, args[0])) {
            return path__namespace.resolve(args[0]);
        }
        return str;
    };
    fs.realpathSync.native = (...args) => {
        const str = origRealpathSyncNative(...args);
        if (isEscape(str, args[0])) {
            return path__namespace.resolve(args[0]);
        }
        return str;
    };
    fs.readlinkSync = (...args) => {
        args[0] = path__namespace.resolve(args[0]);
        const str = path__namespace.resolve(path__namespace.dirname(args[0]), origReadlinkSync(...args));
        if (isEscape(str, args[0]) || str === args[0]) {
            const e = new Error("EINVAL: invalid argument, readlink '" + args[0] + "'");
            e.code = 'EINVAL';
            throw e;
        }
        return str;
    };
    fs.readdir = (...args) => {
        const p = path__namespace.resolve(
          // node 20.12 tightened the constraints and requires the input to be a string
          String(args[0]),
        );
        let cb = args[args.length - 1];
        if (typeof cb !== 'function') {
            // this will likely throw callback required error.
            return origReaddir(...args);
        }
        cb = once(cb);
        args[args.length - 1] = (err, result) => {
            if (err) {
                return cb(err);
            }
            // user requested withFileTypes
            if (result[0] && result[0].isSymbolicLink) {
                Promise
                    .all(result.map((v) => handleDirent(p, v)))
                    .then(() => {
                    cb(null, result);
                })
                    .catch(err => {
                    cb(err);
                });
            }
            else {
                // string array return for readdir.
                cb(null, result);
            }
        };
        origReaddir(...args);
    };
    fs.readdirSync = (...args) => {
        const res = origReaddirSync(...args);
        const p = path__namespace.resolve(
          // node 20.12 tightened the constraints and requires the input to be a string
          String(args[0]),
        );
        res.forEach((v) => {
            handleDirentSync(p, v);
        });
        return res;
    };
    // i need to use this twice in bodt readdor and readdirSync. maybe in fs.Dir
    function patchDirent(dirent, stat) {
        // add all stat is methods to Dirent instances with their result.
        for (const i in stat) {
            if (i.indexOf('is') === 0 && typeof stat[i] === 'function') {
                //
                const result = stat[i]();
                if (result) {
                    dirent[i] = () => true;
                }
                else {
                    dirent[i] = () => false;
                }
            }
        }
    }
    if (fs.opendir) {
        const origOpendir = fs.opendir.bind(fs);
        // tslint:disable-next-line:no-any
        fs.opendir = (...args) => {
            let cb = args[args.length - 1];
            // if this is not a function opendir should throw an error.
            // we call it so we don't have to throw a mock
            if (typeof cb === 'function') {
                cb = once(cb);
                args[args.length - 1] = async (err, dir) => {
                    try {
                        cb(null, await handleDir(dir));
                    }
                    catch (e) {
                        cb(e);
                    }
                };
                origOpendir(...args);
            }
            else {
                return origOpendir(...args).then((dir) => {
                    return handleDir(dir);
                });
            }
        };
    }
    async function handleDir(dir) {
        const p = path__namespace.resolve(dir.path);
        const origIterator = dir[Symbol.asyncIterator].bind(dir);
        // tslint:disable-next-line:no-any
        const origRead = dir.read.bind(dir);
        dir[Symbol.asyncIterator] = async function* () {
            for await (const entry of origIterator()) {
                await handleDirent(p, entry);
                yield entry;
            }
        };
        // tslint:disable-next-line:no-any
        dir.read = async (...args) => {
            if (typeof args[args.length - 1] === 'function') {
                const cb = args[args.length - 1];
                args[args.length - 1] = async (err, entry) => {
                    cb(err, entry ? await handleDirent(p, entry) : null);
                };
                origRead(...args);
            }
            else {
                const entry = await origRead(...args);
                if (entry) {
                    await handleDirent(p, entry);
                }
                return entry;
            }
        };
        // tslint:disable-next-line:no-any
        const origReadSync = dir.readSync.bind(dir);
        // tslint:disable-next-line:no-any
        dir.readSync = () => {
            return handleDirentSync(p, origReadSync());
        };
        return dir;
    }
    let handleCounter = 0;
    function handleDirent(p, v) {
        handleCounter++;
        return new Promise((resolve, reject) => {
            if (fs.DEBUG) {
                console.error(handleCounter + ' opendir: found link? ', path__namespace.join(p, v.name), v.isSymbolicLink());
            }
            if (!v.isSymbolicLink()) {
                return resolve(v);
            }
            const linkName = path__namespace.join(p, v.name);
            origReadlink(linkName, (err, target) => {
                if (err) {
                    return reject(err);
                }
                if (fs.DEBUG) {
                    console.error(handleCounter + ' opendir: escapes? [target]', path__namespace.resolve(target), '[link] ' + linkName, isEscape(path__namespace.resolve(target), linkName), roots);
                }
                if (!isEscape(path__namespace.resolve(target), linkName)) {
                    return resolve(v);
                }
                fs.stat(target, (err, stat) => {
                    if (err) {
                        if (err.code === 'ENOENT') {
                            if (fs.DEBUG) {
                                console.error(handleCounter + ' opendir: broken link! resolving to link ', path__namespace.resolve(target));
                            }
                            // this is a broken symlink
                            // even though this broken symlink points outside of the root
                            // we'll return it.
                            // the alternative choice here is to omit it from the directory listing altogether
                            // this would add complexity because readdir output would be different than readdir
                            // withFileTypes unless readdir was changed to match. if readdir was changed to match
                            // it's performance would be greatly impacted because we would always have to use the
                            // withFileTypes version which is slower.
                            return resolve(v);
                        }
                        // transient fs related error. busy etc.
                        return reject(err);
                    }
                    if (fs.DEBUG) {
                        console.error(handleCounter + " opendir: patching dirent to look like it's target", path__namespace.resolve(target));
                    }
                    // add all stat is methods to Dirent instances with their result.
                    patchDirent(v, stat);
                    v.isSymbolicLink = () => false;
                    resolve(v);
                });
            });
        });
    }
    function handleDirentSync(p, v) {
        if (v && v.isSymbolicLink) {
            if (v.isSymbolicLink()) {
                // any errors thrown here are valid. things like transient fs errors
                const target = path__namespace.resolve(p, origReadlinkSync(path__namespace.join(p, v.name)));
                if (isEscape(target, path__namespace.join(p, v.name))) {
                    // Dirent exposes file type so if we want to hide that this is a link
                    // we need to find out if it's a file or directory.
                    v.isSymbolicLink = () => false;
                    // tslint:disable-next-line:no-any
                    const stat = origStatSync(target);
                    // add all stat is methods to Dirent instances with their result.
                    patchDirent(v, stat);
                }
            }
        }
    }
    /**
     * patch fs.promises here.
     *
     * this requires a light touch because if we trigger the getter on older nodejs versions
     * it will log an experimental warning to stderr
     *
     * `(node:62945) ExperimentalWarning: The fs.promises API is experimental`
     *
     * this api is available as experimental without a flag so users can access it at any time.
     */
    const promisePropertyDescriptor = Object.getOwnPropertyDescriptor(fs, 'promises');
    if (promisePropertyDescriptor) {
        // tslint:disable-next-line:no-any
        const promises = {};
        promises.lstat = util__namespace.promisify(fs.lstat);
        // NOTE: node core uses the newer realpath function fs.promises.native instead of fs.realPath
        promises.realpath = util__namespace.promisify(fs.realpath.native);
        promises.readlink = util__namespace.promisify(fs.readlink);
        promises.readdir = util__namespace.promisify(fs.readdir);
        if (fs.opendir) {
            promises.opendir = util__namespace.promisify(fs.opendir);
        }
        // handle experimental api warnings.
        // only applies to version of node where promises is a getter property.
        if (promisePropertyDescriptor.get) {
            const oldGetter = promisePropertyDescriptor.get.bind(fs);
            const cachedPromises = {};
            promisePropertyDescriptor.get = () => {
                const _promises = oldGetter();
                Object.assign(cachedPromises, _promises, promises);
                return cachedPromises;
            };
            Object.defineProperty(fs, 'promises', promisePropertyDescriptor);
        }
        else {
            // api can be patched directly
            Object.assign(fs.promises, promises);
        }
    }
}
function isOutPath(root, str) {
    return !root || (!str.startsWith(root + path__namespace.sep) && str !== root);
}
function escapeFunction(roots) {
    // ensure roots are always absolute
    roots = roots.map(root => path__namespace.resolve(root));
    function isEscape(linkTarget, linkPath) {
        if (!path__namespace.isAbsolute(linkPath)) {
            linkPath = path__namespace.resolve(linkPath);
        }
        if (!path__namespace.isAbsolute(linkTarget)) {
            linkTarget = path__namespace.resolve(linkTarget);
        }
        for (const root of roots) {
            if (isOutPath(root, linkTarget) && !isOutPath(root, linkPath)) {
                // don't escape out of the root
                return true;
            }
        }
        return false;
    }
    return { isEscape, isOutPath };
}
function once(fn) {
    let called = false;
    return (...args) => {
        if (called) {
            return;
        }
        called = true;
        let err = false;
        try {
            fn(...args);
        }
        catch (_e) {
            err = _e;
        }
        // blow the stack to make sure this doesn't fall into any unresolved promise contexts
        if (err) {
            setImmediate(() => {
                throw err;
            });
        }
    };
}

function patcher(requireScriptName, nodeDir) {
    requireScriptName = path__namespace.resolve(requireScriptName);
    nodeDir = nodeDir || path__namespace.join(path__namespace.dirname(requireScriptName), '_node_bin');
    const file = path__namespace.basename(requireScriptName);
    try {
        fs__namespace.mkdirSync(nodeDir, { recursive: true });
    }
    catch (e) {
        // with node versions that don't have recursive mkdir this may throw an error.
        if (e.code !== 'EEXIST') {
            throw e;
        }
    }
    let nodeEntry;
    let nodeEntryContent;
    if (process.platform === 'win32') {
        nodeEntry = path__namespace.join(nodeDir, 'node.bat');
        nodeEntryContent = `@if not defined DEBUG_HELPER @ECHO OFF
set NP_SUBPROCESS_NODE_DIR=${nodeDir}
set Path=${nodeDir};%Path%
"${process.execPath}" ${process.env.NODE_REPOSITORY_ARGS} --require "${requireScriptName}" %*
`;
    }
    else {
        nodeEntry = path__namespace.join(nodeDir, 'node');
        nodeEntryContent = `#!/bin/bash
export NP_SUBPROCESS_NODE_DIR="${nodeDir}"
export PATH="${nodeDir}":\$PATH
if [[ ! "\${@}" =~ "${file}" ]]; then
exec ${process.execPath} ${process.env.NODE_REPOSITORY_ARGS} --require "${requireScriptName}" "$@"
else
exec ${process.execPath} ${process.env.NODE_REPOSITORY_ARGS} "$@"
fi
`;
    }
    try {
        fs__namespace.writeFileSync(nodeEntry, nodeEntryContent, process.platform === 'win32' ? undefined : { mode: 0o777 });
    }
    catch (e) {
        if (e.code !== 'EEXIST') {
            throw e;
        }
    }
    // Override PATH
    if (!process.env.PATH) {
        process.env.PATH = nodeDir;
    }
    else if (process.env.PATH.indexOf(nodeDir + path__namespace.delimiter) === -1) {
        process.env.PATH = nodeDir + path__namespace.delimiter + process.env.PATH;
    }
    // fix execPath so folks use the proxy node
    if (process.platform == 'win32') ;
    else {
        process.argv[0] = process.execPath = path__namespace.join(nodeDir, 'node');
    }
    // replace any instances of require script in execArgv with the absolute path to the script.
    // example: bazel-require-script.js
    process.execArgv.map(v => {
        if (v.indexOf(file) > -1) {
            return requireScriptName;
        }
        return v;
    });
    // RBE HACK Explicitly share location of node entry
    process.env.CUSTOM_NODE_ENTRY = nodeEntry;
}

// NOTE Trailing '/' not included in matcher to cover all scenarios (e.g. RUNFILES_DIR environment variable)
const runfilesPathMatcher = '.runfiles';
/**
 * Infers a runfiles directory from the given path, throwing on failure.
 * @param maybeRunfilesSource Path to inspect.
 */
function inferRunfilesDirFromPath(maybeRunfilesSource) {
    while (maybeRunfilesSource !== '/') {
        if (maybeRunfilesSource.endsWith(runfilesPathMatcher)) {
            return maybeRunfilesSource + '/';
        }
        maybeRunfilesSource = path__namespace.dirname(maybeRunfilesSource);
    }
    throw new Error('Path does not contain a runfiles parent directory.');
}
const removeNulls = (value) => value != null;
function runfilesLocator() {
    // Sometimes cwd is under runfiles
    const cwd = process.cwd();
    // Runfiles environment variables are the preferred reference point, but can fail
    const envRunfilesCanidates = [
        process.env.RUNFILES_DIR,
        process.env.RUNFILES,
    ].filter(removeNulls).map(runfilesDir => {
        const adjustedRunfilesDir = fs__namespace.realpathSync(runfilesDir);
        if (runfilesDir !== adjustedRunfilesDir) {
            return adjustedRunfilesDir;
        }
        return runfilesDir;
    });
    // Infer runfiles dir
    for (const maybeRunfilesSource of [...envRunfilesCanidates, cwd]) {
        try {
            return inferRunfilesDirFromPath(maybeRunfilesSource);
        }
        catch (err) {
            // na-da
        }
    }
    throw new Error('Could not resolve runfiles directory from any data sources.');
}
/**
 * Helper to locate bundle (`node_patches.js`) under runfiles.
 * Implementation is depth sensitive, if bundle is moved this needs to be updated.
 */
function resolveBundleUnderRunfiles(bundlePath, runfilesPath) {
    // Get external repos path
    // /__output-base__/external/__external-repo__/internal/node/node_patches.js
    // -> /__output-base__/external/
    const externalReposPath = path__namespace.join(bundlePath, '../../../../');
    // Get bundle path relative to /external/
    // /__output-base__/external/__external-repo__/internal/node/node_patches.js
    // - /__output-base__/external/
    // -> __external-repo__/internal/node/node_patches.js
    const bundleRelativeToRunfiles = path__namespace.relative(externalReposPath, bundlePath);
    // Produce path under runfiles
    // /__output-base__/execroot/__workspace-name__/bazel-out/__output-config__/bin/foo.runfiles/
    // + __external-repo__/internal/node/node_patches.js
    // -> /__output-base__/execroot/__workspace-name__/bazel-out/__output-config__/bin/foo.runfiles/__external-repo__/internal/node/node_patches.js
    return path__namespace.join(runfilesPath, bundleRelativeToRunfiles);
}

const { 
// Used by fs patcher to detect escapes, and potentially redirect reads/writes
BAZEL_PATCH_ROOTS, 
// Set by subprocess patcher, initially generated from `selfUnderRunfilesPath`
NP_SUBPROCESS_NODE_DIR, 
// Run Bazel with --define=VERBOSE_LOGS=1 to enable logging
VERBOSE_LOGS, } = process.env;
// Patch 'fs' module
if (BAZEL_PATCH_ROOTS) {
    const roots = BAZEL_PATCH_ROOTS ? BAZEL_PATCH_ROOTS.split(',') : [];
    if (VERBOSE_LOGS) {
        console
            .error(`bazel node patches enabled. roots: ${roots} symlinks in these directories will not escape`);
    }
    const fs = require('fs');
    patcher$1(fs, roots);
}
else if (VERBOSE_LOGS) {
    console.error(`bazel node patches disabled. set environment BAZEL_PATCH_ROOTS`);
}
return;/*disabled to mitigate #incident-20231108-inspiring-flourish*/// Patch subprocess logic
const selfUnderRunfiles = resolveBundleUnderRunfiles(__filename, runfilesLocator());
patcher(selfUnderRunfiles, NP_SUBPROCESS_NODE_DIR);
