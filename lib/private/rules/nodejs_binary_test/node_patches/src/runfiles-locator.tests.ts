import { resolveBundleUnderRunfiles, RunfilesDirPath } from './runfiles-locator.js';

describe(resolveBundleUnderRunfiles.name, () => {
  it('produces expected path', () => {
    const expected =
      '/___/execroot/__workspace-name__/bazel-out/__output-config__/bin/foo.runfiles/__external-repo__/internal/node/node_patches.js';
    const actual = resolveBundleUnderRunfiles(
      '/___/external/__external-repo__/internal/node/node_patches.js',
      '/___/execroot/__workspace-name__/bazel-out/__output-config__/bin/foo.runfiles/' as RunfilesDirPath,
    );
    expect(actual).toBe(expected);
  });
});
