import * as fs from 'fs';
import * as path from 'path';

// Run Bazel with --define=VERBOSE_LOGS=1 to enable this logging
const VERBOSE_LOGS = !!process.env['VERBOSE_LOGS'];

function log(...m: string[]): void {
    if (VERBOSE_LOGS) {
        console.error(loggingPrefix, ...m);
    }
}

function fatal(context: string, errors: Error[]): never {
    console.error(loggingPrefix, 'Error(s) were reported.');
    console.error(loggingPrefix, 'Context:', context);
    for (const error of errors) {
        console.error(error);
    }
    console.error(loggingPrefix, 'Exiting');
    process.exit(1);
}

/** Runfiles directory path. e.g. `/__output_base__/execroot/com_canva_canva/bazel-out/___/bin/___/___.runfiles/web_node_modules/node_modules` */
export type RunfilesDirPath = string & { __RunfilesDirPath: never };
/** Mount point for `node_modules` relative to workspace root. e.g. `web`, `web/tools/cloudflare` */
export type RelativeMountPath = string & { __RelativeMountPath: never };
/** A workspace name. e.g. `com_canva_canva`, `rules_nodejs`, `web_node_modules` */
export type WorkspaceName = string & { __RepositoryName: never };

/**
 * Manifest defining `node_modules` mounts that need to be created, and for which workspace.
 * File defined in `@rules_nodejs//internal/linker/link_node_modules.bzl`
 */
type ModulesManifest = {
    roots: Record<RelativeMountPath, WorkspaceName>,
    workspace: WorkspaceName,
};

/** Path for symlink file (aka link name). */
type SymlinkFilePath = string & { __SymlinkFilePath: never };
/** Path for symlink target. */
type SymlinkTargetPath = string & { __SymlinkTargetPath: never };
/** Describes potential symlinks. */
type ProposedSymlink = [filePath: SymlinkFilePath, targetPath: SymlinkTargetPath];

// NOTE Trailing '/' not included in matcher to cover all scenarios (e.g. RUNFILES_DIR environment variable)
const runfilesPathMatcher = '.runfiles';
const nodeModulesDir = 'node_modules';
const loggingPrefix = '[node_modules-linker]';

/**
 * Infers a runfiles directory from the given path, throwing on failure.
 * @param maybeRunfilesSource Path to inspect.
 */
export function inferRunfilesDirFromPath(maybeRunfilesSource: string): RunfilesDirPath {
    while (maybeRunfilesSource !== '/') {
        if (maybeRunfilesSource.endsWith(runfilesPathMatcher)) {
            return (maybeRunfilesSource + '/') as RunfilesDirPath;
        }

        maybeRunfilesSource = path.dirname(maybeRunfilesSource);
    }

    throw new Error('Path does not contain a runfiles parent directory.');
}

/**
 * Gets the symlinks required to satisfy `node_modules` linking requirements.
 * @param modulesManifest Modules manifest to read `node_modules` roots from.
 * @param runfilesDirPath Runfiles directory symlinks should operate within.
 */
export function getProposedSymlinks(
    modulesManifest: ModulesManifest,
    runfilesDirPath: RunfilesDirPath,
): ProposedSymlink[] {
    const symlinks: ProposedSymlink[] = [];

    let relativeMountParent: RelativeMountPath;
    for (relativeMountParent in modulesManifest.roots) {
        const repositoryName = modulesManifest.roots[relativeMountParent];
        const filePath = path.join(
            runfilesDirPath,
            modulesManifest.workspace,
            relativeMountParent,
            nodeModulesDir,
        ) as SymlinkFilePath;
        const targetPath = path.join(
            runfilesDirPath,
            repositoryName,
            nodeModulesDir,
        ) as SymlinkTargetPath;
        symlinks.push([filePath, targetPath]);
    }

    return symlinks;
}

/**
 * @todo Replace with `error.cause` once on NodeJS >=16.9
 */
function ensureErrorInstance(err: unknown): Error {
    return err instanceof Error
        ? err
        : new Error(`Non-error thrown, value was "${err ?? 'NULL_OR_UNDEFINED'}"`);
}

function tryRun<T>(func: () => T): Error | T {
    try {
        return func();
    } catch (err) {
        return ensureErrorInstance(err);
    }
}

function definedOrThrow<T>(value: T, throwReason: string): Exclude<T, null | undefined> {
    if (value == null) {
        throw new Error(throwReason);
    }

    return value as Exclude<T, null | undefined>;
}

/**
 * Creates symlink using a "try-else-check" approach to safeguard against concurrent creation.
 * On failure the (assumed to exist) symlink is inspected, an error is thrown if the target path
 * differs.
 */
export function tryCreateSymlink(filePath: SymlinkFilePath, targetPath: SymlinkTargetPath): void {
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
            throw new Error(
                `Invalid symlink target path "${readlinkResult}" detected, wanted "${targetPath}" for symlink at "${filePath}"`,
            );
        }

        log('symlink already exists');
    }
}

const removeNulls = <S>(value: S | undefined): value is S => value != null;

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
                log(
                    `Symlink dereferenced from runfiles path. Was "${runfilesDir}" now "${adjustedRunfilesDir}"`,
                );
                return adjustedRunfilesDir;
            }
            return runfilesDir;
        });

    // Infer runfiles dir

    const runfilesDirPath: RunfilesDirPath = (() => {
        for (const maybeRunfilesSource of [...envRunfilesCanidates, cwd]) {
            try {
                log(`Attempting to infer runfiles directory from "${maybeRunfilesSource}"`);
                return inferRunfilesDirFromPath(maybeRunfilesSource);
            } catch (err) {
                log(
                    `Could not resolve runfiles directory from "${maybeRunfilesSource}"`,
                    ensureErrorInstance(err).message,
                );
            }
        }
        throw new Error('Could not resolve runfiles directory from any data sources.');
    })();
    log('Resolved runfiles path:', runfilesDirPath);

    // Get required links from modules manifest

    const modulesManifestPath = definedOrThrow(
        process.argv[2],
        'argv[2] is required to locate modules manifest but is missing.',
    );
    log('Modules manifest path:', modulesManifestPath);

    const modulesManifestContent = fs.readFileSync(modulesManifestPath, 'utf-8');
    const modulesManifest = JSON.parse(modulesManifestContent) as ModulesManifest;
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
    } catch (err) {
        fatal('unhandled exception', [ensureErrorInstance(err)]);
    }
}
