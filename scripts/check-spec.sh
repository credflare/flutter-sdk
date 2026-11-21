#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
spec="${SDK_SPEC_DIR:-../sdk-spec}"
node "$spec/scripts/generate.mjs" --target dart --out lib/src/spec.generated.dart --check
diff -r "$spec/fixtures" test/fixtures
