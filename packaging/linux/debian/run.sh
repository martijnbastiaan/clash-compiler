#!/bin/bash
set -x
set -e

echo "Please read the instructions in debian/rules if this is your first time building a Debian package"

sleep 3

cp -ap packaging/linux/debian .

BASE_VERSION=${1}
SUB_VERSION=${2}
DISTRO=${3}

DATE=$(date --rfc-2822)
PGP_NAME="Martijn Bastiaan (Martijn Bastiaan at QBayLogic B.V.) <martijn@qbaylogic.com>"

tar --exclude=.git --exclude-vcs-ignores  -zcf ../clash_${BASE_VERSION}.${SUB_VERSION}.orig.tar.gz .

case ${DISTRO} in
    xenial|bionic) ;;
    *) echo Not a valid distibution: ${DISTRO}.; exit 1; ;;
esac

sudo mkdir -p /opt/clash

sudo pbuilder create --distribution bionic --othermirror "deb http://archive.ubuntu.com/ubuntu $DISTRO main restricted universe multiverse|deb http://ppa.launchpad.net/hvr/ghc/ubuntu $DISTRO main"

sed -i "s/__BASE_VERSION__/${BASE_VERSION}/g" debian/{control,rules,changelog}
sed -i "s/__SUB_VERSION__/${SUB_VERSION}/g"   debian/{control,rules,changelog}
sed -i "s/__DISTRO__/${DISTRO}/g"             debian/{control,rules,changelog}
sed -i "s/__DATE__/${DATE}/g"                 debian/{control,rules,changelog}
sed -i "s/__PGP_NAME__/${PGP_NAME}/g"         debian/{control,rules,changelog}

pdebuild

ls /var/cache/pbuilder/result/
