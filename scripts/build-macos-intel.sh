#!/usr/bin/env bash
set -euo pipefail
if [[ "$(uname -s)" != Darwin ]]; then
  echo 'This script requires macOS with Xcode Command Line Tools.' >&2
  exit 1
fi
cd "${1:?Usage: bash build-macos-intel.sh /path/to/sigma-file-manager}"
xcode-select -p
node -e "const [a,b]=process.versions.node.split('.').map(Number);if(a<24||(a===24&&b<16))throw Error('Node >=24.16 required')"
command -v cargo >/dev/null
rustup target add x86_64-apple-darwin
npm ci
mkdir -p node_modules/.cloud
cat > node_modules/.cloud/macos.vite.config.ts <<'CONFIG'
import config from '../../vite.config';
export default {
  ...config,
  plugins: config.plugins.filter((plugin: any) => plugin?.name !== 'vite:plugin:run'),
  build: { ...config.build, target: 'safari15.6', cssTarget: 'safari15.6' },
};
CONFIG
node --input-type=module <<'CONFIG'
import fs from 'node:fs';
const config = JSON.parse(fs.readFileSync('src-tauri/tauri.conf.json', 'utf8'));
const override = {
  build: { beforeBuildCommand: 'npm run ts && npm run build-only -- --config node_modules/.cloud/macos.vite.config.ts' },
  app: { windows: config.app.windows.map(window => ({ ...window, ...(window.transparent ? { transparent: false } : {}) })) },
  bundle: { targets: ['app', 'dmg'], macOS: { minimumSystemVersion: '12.0' } },
};
fs.writeFileSync('node_modules/.cloud/macos-tauri.json', JSON.stringify(override, null, 2));
CONFIG
export MACOSX_DEPLOYMENT_TARGET=12.0
npm run tauri -- build --target x86_64-apple-darwin --bundles app,dmg --config node_modules/.cloud/macos-tauri.json
binary='src-tauri/target/x86_64-apple-darwin/release/bundle/macos/Sigma File Manager.app/Contents/MacOS/sigma-file-manager'
file "$binary"
xcrun vtool -show-build "$binary"
find src-tauri/target/x86_64-apple-darwin/release/bundle -name '*.dmg' -print
