"use strict";
/**
 * @fileoverview NodeJS module loader for bazel.
 */
Object.defineProperty(exports, "__esModule", { value: true });
// Ensure that node is added to the path for any subprocess calls
process.env.PATH = [require('path').dirname(process.execPath), process.env.PATH].join(/^win/i.test(process.platform) ? ';' : ':');
if (require.main === module) {
    // Set the actual entry point in the arguments list.
    // argv[0] == node, argv[1] == entry point.
    // NB: 'TEMPLATED_entry_point_path' & 'TEMPLATED_entry_point' below are replaced during the build process.
    var entryPointPath = 'TEMPLATED_entry_point_path';
    var mainScript = process.argv[1] = entryPointPath;
    try {
        // @ts-expect-error
        module.constructor._load(mainScript, this, /*isMain=*/ true);
    }
    catch (e) {
        // @ts-expect-error
        console.error(e.stack || e);
        process.exit(1);
    }
}
