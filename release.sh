#!/bin/bash

TAG=$(git describe --exact-match HEAD 2>/dev/null)
if [ -z "$TAG" ]
then
	echo "Skipping release: no git tag found."
	exit 0
fi

echo TAG = \"$TAG\"
mkdir -p release
sed -e "s/branch = 'master'/tag = '$TAG'/g" \
    -e "s/version = 'scm-1'/version = '$TAG-1'/g" \
    -e "s/build_target = 'all'/build_target = 'all doc'/g" \
    cluster-scm-1.rockspec > release/cluster-$TAG-1.rockspec

tarantoolctl rocks make release/cluster-$TAG-1.rockspec
tarantoolctl rocks pack cluster $TAG && mv cluster-$TAG-1.all.rock release/

mkdir -p release-doc
cp -RT doc/ release-doc/cluster-$TAG-1
