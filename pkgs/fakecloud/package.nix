# fakecloud, built from the crates.io release tarball.
#
# Source choice (SPEC T2): the published `fakecloud` crate, not a checkout of
# the upstream repo. Upstream is a workspace of ~100 `fakecloud-*` crates and
# this binary is `crates/fakecloud-server` inside it, but the published tarball
# carries its own `Cargo.lock` pinning every sibling at the same 0.44.10, so it
# resolves to exactly the tree the tag was cut from -- the tarball's
# `.cargo_vcs_info.json` records commit 5a560b8818964336d9880ed68e5d7b5471b6849d,
# which is the commit tag `v0.44.10` points at. 223 KB of source instead of a
# 58 MB checkout, for a build of the same binary.
#
# Nothing here vendors or patches upstream (SPEC V17): fetch, build, install.
{
  lib,
  stdenv,
  rustPlatform,
  fetchCrate,
  versionCheckHook,
  pkg-config,
  openssl,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "fakecloud";
  version = "0.44.10";

  src = fetchCrate {
    inherit (finalAttrs) pname version;
    hash = "sha256-vp1XFSl8ArdTYWMh4UYXPXUJtTGgrEhC89eisddFI7I=";
  };

  cargoHash = "sha256-66qf8DjxwkhU3pZbI3FWQwwx7ffatsJY6m9eO3Qty/4=";

  # Platform-conditional, and measured on both (SPEC V27, B2).
  #
  # aarch64-darwin builds this with nothing at all: `native-tls` there goes
  # through Security.framework, so `openssl-sys` is never compiled. On Linux it
  # is, and the build dies at 191 seconds looking for pkg-config and OpenSSL. A
  # green build on one platform said nothing whatsoever about the other.
  #
  # Everything else in the lock that looks like it needs a system library --
  # `libz-sys`, `zstd-sys`, `bzip2-sys`, `lzma-sys`, `ring` -- builds its own
  # vendored C on both platforms, so none of them are listed here.
  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [ pkg-config ];
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [ openssl ];

  doCheck = true;

  # 103 unit tests pass. The one skip is `no_include_str_escapes_its_crate`
  # (SPEC B1, V26): it is not a test of fakecloud's behaviour but a lint over
  # upstream's REPO layout -- it asserts `CARGO_MANIFEST_DIR/..` is a directory
  # called `crates` and then walks its sibling crates' sources. Upstream ships
  # it inside the published tarball, where that layout does not exist, so it
  # cannot pass in any build from crates.io regardless of what the code does.
  # It is inapplicable by construction, which is the only reason a skip is
  # allowed.
  checkFlags = [ "--skip=no_include_str_escapes_its_crate" ];

  preCheck = ''
    # `--skip=<name>` silently accepts a name that no longer exists, so a
    # renamed or deleted test upstream would turn this into a skip of nothing
    # while still looking justified. Assert it is still there (SPEC V26).
    if ! grep -q 'fn no_include_str_escapes_its_crate' tests/no_escaping_include_str.rs; then
      echo "checkFlags skips no_include_str_escapes_its_crate, but that test is gone from the source." >&2
      echo "Re-check whether the skip is still needed instead of skipping nothing." >&2
      exit 1
    fi
  '';

  # Assert the binary we installed is the version we think we built (SPEC V7).
  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckProgramArg = "--version";

  meta = {
    description = "Local AWS cloud emulator, an open-source LocalStack alternative";
    homepage = "https://fakecloud.dev";
    downloadPage = "https://github.com/faiscadev/fakecloud";
    # Upstream is AGPL-3.0-or-later. This repo is packaging only and carries its
    # own licence; see LICENSE and SPEC's licence boundary (SPEC V18).
    license = lib.licenses.agpl3Plus;
    mainProgram = "fakecloud";
    platforms = lib.platforms.unix;
  };
})
