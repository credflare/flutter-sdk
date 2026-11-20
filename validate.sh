#!/bin/sh
set -eu
flutter analyze
flutter test
(cd example && flutter test)
