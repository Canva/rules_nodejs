import * as path from 'path';
import * as patcher from './mod.js';
import { resolveBundleUnderRunfiles, runfilesLocator } from './runfiles-locator.js';

const {
  // Used by fs patcher to detect escapes, and potentially redirect reads/writes
  BAZEL_PATCH_ROOTS,
  // Set by subprocess patcher, initially generated from `selfUnderRunfilesPath`
  NP_SUBPROCESS_NODE_DIR,
  // Run Bazel with --define=VERBOSE_LOGS=1 to enable logging
  VERBOSE_LOGS,
} = process.env;

// Patch 'fs' module
if (BAZEL_PATCH_ROOTS) {
  const roots = BAZEL_PATCH_ROOTS ? BAZEL_PATCH_ROOTS.split(',') : [];
  if (VERBOSE_LOGS) {
    console.error(
      `bazel node patches enabled. roots: ${roots} symlinks in these directories will not escape`,
    );
  }
  const fs = require('fs');
  patcher.fsModule(fs, roots);
} else if (VERBOSE_LOGS) {
  console.error(`bazel node patches disabled. set environment BAZEL_PATCH_ROOTS`);
}

// Patch subprocess logic
const selfUnderRunfiles = resolveBundleUnderRunfiles(__filename, runfilesLocator());
patcher.subprocess(selfUnderRunfiles, NP_SUBPROCESS_NODE_DIR);
