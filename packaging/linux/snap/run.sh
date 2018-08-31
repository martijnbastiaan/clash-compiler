#!/bin/bash
set -x
set -e

echo "Please read the instructions in snapcraft.yaml if this is your first time building a Snap package"

sleep 3

BASE_VERSION=${1}
SUB_VERSION=${2}

cp packaging/linux/snap/snapcraft.yaml .
sed -i "s/__BASE_VERSION__/${BASE_VERSION}/g" snapcraft.yaml
sed -i "s/__SUB_VERSION__/${SUB_VERSION}/g" snapcraft.yaml
snapcraft cleanbuild

mv ../*.snap ~
ls ~/*.snap
