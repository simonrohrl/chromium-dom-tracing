#!/bin/bash
set -e

# 1. Get the hash
REVISION=$(cat .chromium-version)

# 2. Setup depot_tools
if [ ! -d "depot_tools" ]; then
    git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
fi
export PATH="$(pwd)/depot_tools:$PATH"

# 3. Fetch ONLY the specific commit
mkdir -p chromium
cd chromium

if [ ! -d "src" ]; then
    caffeinate fetch --nohooks --no-history chromium --revision="$REVISION"
fi

cd src

gn gen out/Default
cp ../../scripts/assets/args.gn out/Default/args.gn