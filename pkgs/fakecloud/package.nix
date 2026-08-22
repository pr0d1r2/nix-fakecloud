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
  rustPlatform,
  fetchCrate,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "fakecloud";
  version = "0.44.10";

  src = fetchCrate {
    inherit (finalAttrs) pname version;
    hash = "sha256-vp1XFSl8ArdTYWMh4UYXPXUJtTGgrEhC89eisddFI7I=";
  };

  cargoHash = "sha256-66qf8DjxwkhU3pZbI3FWQwwx7ffatsJY6m9eO3Qty/4=";

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
