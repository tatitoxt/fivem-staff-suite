#!/usr/bin/env bash
set -euo pipefail

edition=$1
archive=$2
stage=$(mktemp -d)
trap 'rm -rf -- "$stage"' EXIT
unzip -tq "$archive"
unzip -q "$archive" -d "$stage"
resource="$stage/staff_suite"
test "$(find "$stage" -mindepth 1 -maxdepth 1 -printf '%f')" = staff_suite
test -s "$resource/ui/dist/index.html"
cmp CHANGELOG.md "$resource/CHANGELOG.md"
test -s "$resource/third-party-licenses/react.txt"
test ! -e "$resource/tests"
test ! -e "$resource/plan"
test ! -e "$resource/ui/node_modules"
version=$(sed -n "s/^version '\(.*\)'$/\1/p" fxmanifest.lua)
grep -Fqx "version '$version'" "$resource/fxmanifest.lua"

if [[ $edition == lite ]]; then
  test "${archive##*/}" = "staff_suite_lite-$version.zip"
  grep -qx 'MIT License' "$resource/LICENSE"
  if grep -q escrow_ignore "$resource/fxmanifest.lua"; then exit 1; fi
  test ! -e "$resource/sql"
  test ! -e "$resource/server/bridges"
  test ! -e "$resource/server/main.lua"
  test ! -e "$resource/server/export.lua"
  test ! -e "$resource/server/persist_sql.lua"
  test ! -e "$resource/server/capture.lua"
  test ! -e "$resource/client/moderation.lua"
  test ! -e "$resource/core/duty.lua"
  STAFF_SUITE_LITE_RESOURCE="$resource" lua5.4 -e 'for _, test in pairs(require("tests.test_lite")) do test() end'
else
  test "$edition" = core
  test "${archive##*/}" = "staff_suite-$version.zip"
  grep -q escrow_ignore "$resource/fxmanifest.lua"
  test -d "$resource/sql"
  test -f "$resource/server/main.lua"
  test -f "$resource/server/capture.lua"
  test -f "$resource/client/moderation.lua"
  test ! -e "$resource/server/lite.lua"
  test ! -e "$resource/LICENSE"
fi
