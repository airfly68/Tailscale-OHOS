#!/bin/bash
# macOS port of scripts/build.ps1: wires DevEco's hvigor into the project,
# builds the Go core, then assembles the HAP. Usage: scripts/build.sh [default|release]
set -euo pipefail

Product="${1:-default}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -n "${DEVECO_STUDIO_HOME:-}" && -d "$DEVECO_STUDIO_HOME/sdk" ]]; then
  deveco_home="$DEVECO_STUDIO_HOME"
elif [[ -d "/Applications/DevEco-Studio.app/Contents/sdk" ]]; then
  deveco_home="/Applications/DevEco-Studio.app/Contents"
else
  echo "DevEco Studio was not found. Set DEVECO_STUDIO_HOME." >&2
  exit 1
fi

hvigor_home="$deveco_home/tools/hvigor/hvigor"
hvigor="$hvigor_home/bin/hvigor.js"
# macOS JBR layout differs from Windows
java_home="$deveco_home/jbr/Contents/Home"
node_bin="$deveco_home/tools/node/bin"
sdk_home="${DEVECO_SDK_HOME:-$deveco_home/sdk}"

[[ -f "$hvigor" ]] || { echo "DevEco Hvigor was not found at $hvigor" >&2; exit 1; }

# symlinks stand in for the NTFS junctions used by the PowerShell script
tooling_scope="$ROOT/.tooling/node_modules/@ohos"
mkdir -p "$tooling_scope"
[[ -e "$tooling_scope/hvigor" ]] || ln -s "$hvigor_home" "$tooling_scope/hvigor"
[[ -e "$tooling_scope/hvigor-ohos-plugin" ]] || ln -s "$deveco_home/tools/hvigor/hvigor-ohos-plugin" "$tooling_scope/hvigor-ohos-plugin"

export JAVA_HOME="$java_home"
export PATH="$java_home/bin:$node_bin:$PATH"
export DEVECO_SDK_HOME="$sdk_home"
export OHOS_SDK_HOME="$sdk_home"
export HVIGOR_USER_HOME="$ROOT/.hvigor-user"
export NODE_PATH="$ROOT/.tooling/node_modules:$hvigor_home/node_modules:$deveco_home/tools/hvigor/hvigor-ohos-plugin/node_modules"

"$ROOT/scripts/build-go.sh"

node "$hvigor" --mode module -p module=entry@default -p product="$Product" assembleHap --no-daemon

find "$ROOT/entry/build" -name '*.hap' -print
