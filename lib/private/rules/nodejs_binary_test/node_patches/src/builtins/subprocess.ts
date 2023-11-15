import * as fs from 'fs';
import * as path from 'path';

export function patcher(requireScriptName: string, nodeDir?: string) {
  requireScriptName = path.resolve(requireScriptName);
  nodeDir = nodeDir || path.join(path.dirname(requireScriptName), '_node_bin');
  const file = path.basename(requireScriptName);

  try {
    fs.mkdirSync(nodeDir, { recursive: true });
  } catch (e: any) {
    // with node versions that don't have recursive mkdir this may throw an error.
    if (e.code !== 'EEXIST') {
      throw e;
    }
  }

  let nodeEntry: string;
  let nodeEntryContent: string;
  if (process.platform === 'win32') {
    nodeEntry = path.join(nodeDir, 'node.bat');
    nodeEntryContent = `@if not defined DEBUG_HELPER @ECHO OFF
set NP_SUBPROCESS_NODE_DIR=${nodeDir}
set Path=${nodeDir};%Path%
"${process.execPath}" ${process.env.NODE_REPOSITORY_ARGS} --require "${requireScriptName}" %*
`;
  } else {
    nodeEntry = path.join(nodeDir, 'node');
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
    fs.writeFileSync(
      nodeEntry,
      nodeEntryContent,
      process.platform === 'win32' ? undefined : { mode: 0o777 },
    );
  } catch (e: any) {
    if (e.code !== 'EEXIST') {
      throw e;
    }
  }

  // Override PATH
  if (!process.env.PATH) {
    process.env.PATH = nodeDir;
  } else if (process.env.PATH.indexOf(nodeDir + path.delimiter) === -1) {
    process.env.PATH = nodeDir + path.delimiter + process.env.PATH;
  }

  // fix execPath so folks use the proxy node
  if (process.platform == 'win32') {
    // FIXME: need to make an exe, or run in a shell so we can use .bat
  } else {
    process.argv[0] = process.execPath = path.join(nodeDir, 'node');
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
