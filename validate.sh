#!/bin/sh
set -eu
sh scripts/check-spec.sh
flutter analyze
flutter test
(cd example && flutter test)
