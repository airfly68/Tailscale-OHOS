# Building on macOS

`scripts/build.sh` is a macOS port of `scripts/build.ps1`. It drives the same
pipeline: bootstrap checks → Go c-shared core → hvigor `assembleHap`.

## Prerequisites

- DevEco Studio for Mac (HarmonyOS SDK embedded; the native SDK with
  `aarch64-linux-ohos` clang/sysroot lives inside the app bundle).
- A host Go toolchain ≥ 1.22.6 to bootstrap the OpenHarmony Go fork
  (official `go1.24.5.darwin-arm64.tar.gz` works well).
- Node.js is taken from DevEco's bundled runtime.

## One-time: build the GOOS=openharmony toolchain

The Gitee mirror of `ohos_golang_go` only carries the old go1.22-based master.
The maintained go1.24 line lives on GitCode:

```bash
git clone --depth 1 -b release-branch.go1.24 \
  https://gitcode.com/openharmony-sig/ohos_golang_go.git third_party/ohos-go
git -C third_party/ohos-go apply patches/ohos-go-interface-resources.patch
cd third_party/ohos-go/src
GOROOT_BOOTSTRAP=/path/to/go1.24.5.darwin-arm64 GOTOOLCHAIN=local ./make.bash
```

## Build

```bash
./scripts/build.sh            # unsigned HAP
./scripts/build.sh release    # release product (requires changelog check)
```

The signed-HAP flow is unchanged: configure signing in DevEco
(File > Project Structure > Signing Configs) and re-run the script; the
artifact lands in `entry/build/default/outputs/default/`.

## Gotchas

- **Keep the toolchain and Go caches off network/exFAT-style volumes.** Self-hosting
  (`make.bash`) writes binaries and immediately mmaps them for execution; on
  volumes that don't serve freshly written executables reliably this fails with
  `signal: bus error`. `scripts/build-go.sh` therefore prefers
  `~/.ohos-go-build/ohos-go` as GOROOT and keeps `GOCACHE`/`GOMODCACHE`/`GOPATH`
  on the internal disk; project sources are only read, and only the final
  `.so` is written back to the project directory.
- Module downloads use `GOPROXY=https://goproxy.cn,https://proxy.golang.org,direct`
  by default; override `GOPROXY` if you have another preferred proxy.
