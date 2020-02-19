#!/bin/bash

set -e

if [ -n "$CI_COMMIT_TAG" ]
then
    TAG="$CI_COMMIT_TAG"
else
    TAG=$(git describe --exact-match HEAD 2>/dev/null || true)
fi

if [ -z "$TAG" ]
then
    echo "No git tag found. Skipping release."
    exit 0
fi

echo "Preparing release \"$TAG\""
mkdir -p release
sed -e "s/branch = '.\+'/tag = '$TAG'/g" \
    -e "s/version = '.\+'/version = '$TAG-1'/g" \
    cartridge-scm-1.rockspec > release/cartridge-$TAG-1.rockspec

tarantoolctl rocks make release/cartridge-$TAG-1.rockspec
tarantoolctl rocks pack cartridge $TAG && mv cartridge-$TAG-1.all.rock release/

mkdir -p release-doc
cp -RT doc/ release-doc/cartridge-$TAG-1
