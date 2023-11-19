#!/bin/sh -e
#
#  Copyright 2020, Roger Brown
#
#  This file is part of rhubarb pi.
#
#  This program is free software: you can redistribute it and/or modify it
#  under the terms of the GNU General Public License as published by the
#  Free Software Foundation, either version 3 of the License, or (at your
#  option) any later version.
# 
#  This program is distributed in the hope that it will be useful, but WITHOUT
#  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
#  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
#  more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>
#
# $Id: package.sh 250 2023-04-15 06:28:32Z rhubarb-geek-nz $
#

. /etc/os-release

PACKAGE=powershell
USCORE=_
SRCPKG="${PACKAGE}.pkg"
SRCTAR="${PACKAGE}.tar"
VERSION="$1"
MAKE_RPM=false
MAKE_DEB=false

umask 022

if test -z "$VERSION"
then
	VERSION=7.4.0
fi

if test -z "$MAINTAINER"
then
	if git config user.email > /dev/null
	then
		MAINTAINER="$(git config user.email)"
	else
		MAINTAINER="$LOGNAME@$HOSTNAME"
	fi
fi

REPOS="https://github.com/PowerShell/PowerShell/releases/download/v${VERSION}"

rm -rf control data

cleanup()
{
	for d in data control rpms
	do
		if test -d "$d"
		then
			chmod -R +w "$d"
			rm -rf "$d"
		fi
	done
	rm -rf data.tar.xz control.tar.xz debian-binary  "${SRCPKG}" "${SRCTAR}" rpm.spec
}

trap cleanup 0

wget()
{
	curl --silent --fail --location --output $(basename "$1") "$1"
}

first()
{
	echo "$1"
}

test -n "${VERSION}"

ARCHDPKG=`uname -m`	

case "$ARCHDPKG" in
	armhf | armv7l )
		ARCHTAR=arm32
		;;
	aarch64 )
		ARCHTAR=arm64
		;;
	x86_64 )
		ARCHTAR=x64
		;;
	* )
		ARCHTAR="$ARCHDPKG"
		;;
esac

for d in $ID $ID_LIKE
do
	echo Looking for $d

	SRCPKG=

	case "$d" in
		debian | ubuntu )
			ARCHORIG="amd64"
			SRCPKG="${PACKAGE}${USCORE}${VERSION}-1.deb${USCORE}${ARCHORIG}.deb"
			;;
		centos | rhel | fedora )
			ARCHORIG="x86_64"
			SRCPKG="${PACKAGE}-${VERSION}-1.rh.${ARCHORIG}.rpm"
			;;
		mariner )
			ARCHORIG="x86_64"
			SRCPKG="${PACKAGE}-${VERSION}-1.cm.${ARCHORIG}.rpm"
			;;
		* )
			;;
	esac

	if test -n "$SRCPKG"
	then
		if wget "${REPOS}/${SRCPKG}"
		then
			break
		fi
	fi
done

SRCTAR="${PACKAGE}-${VERSION}-linux-${ARCHTAR}.tar.gz"

if test ! -f "${SRCTAR}"
then
	wget "${REPOS}/${SRCTAR}"
fi

ls -ld "${SRCPKG}" "${SRCTAR}"

case "${SRCPKG}" in
	*.deb )
		MAKE_DEB=true
		dpkg --print-architecture
		ARCHDPKG=`dpkg --print-architecture`

		ar t "${SRCPKG}" | while read N
		do
			echo "$N"

			case "$N" in 
				control.tar.xz )
				ar p "${SRCPKG}" "$N" | (
					set -e
					mkdir control
					cd control
					tar xvfJ -
				)
				;;
			control.tar.gz )
				ar p "${SRCPKG}" "$N" | (
					set -e
					mkdir control
					cd control
					tar xvfz -
				)
				;;
			data.tar.xz )
				ar p "${SRCPKG}" "$N" | (
					set -e
					mkdir data
					cd data
					tar xfJ - 
				)
			;;
			data.tar.gz )
				ar p "${SRCPKG}" "$N" | (
					set -e
					mkdir data
					cd data
					tar xfz - 
				)
				;;
			debian-binary )
				ar x "${SRCPKG}" "$N"
				;;
			* )
				;;
			esac
		done
		;;
	*.rpm )
		MAKE_RPM=true
		rpm2cpio "${SRCPKG}" | (
			set -e
			mkdir data
			cd data
			cpio -idm
		)
		mkdir control
		rpm -qip "${SRCPKG}" > control/values
		cat control/values
		;;
	* )
		;;
esac

rm "${SRCPKG}"

SRCPKG="${SRCPKG}.deleted"

(
	set -e
	cd data
	CD=`find . -type f -name pwsh`
	test -n "$CD"
	DN=`dirname "$CD"`
	echo deleting "$DN"
	rm -rf "$DN"
	echo creating "$DN"
	mkdir "$DN"
	cd "$DN"
	tar xfz -
	ls -ld "./pwsh"
	find . -type f | xargs chmod -x
	chmod +x "./pwsh"
	ldd "./pwsh"
	"./pwsh" -Version
	ACTUALVERS=$("./pwsh" -Version | while read A B C; do echo $B; break; done)
	test "$VERSION" = "$ACTUALVERS"
) < "${SRCTAR}"


LENDATA=`du -sk data`
LENDATA=`first ${LENDATA}`
MAINTORIG=

if test -f control/control
then
	LENORIG=

	while read A B
	do
		case "$A" in
		Installed-Size: )
			LENORIG="$B"
			;;
		Architecture: )
			ARCHORIG="$B"	
			;;
		Version: )
			VERSION="$B"
			;;
		Package: )
			PACKAGE="$B"
			;;
		Maintainer: )
			MAINTORIG="$B"
			;;
		* )
			;;
		esac
	done < control/control

	sed "s/Installed-Size: ${LENORIG}/Installed-Size: ${LENDATA}/" <control/control >control/control.size
	mv control/control.size control/control

	sed "s/Architecture: ${ARCHORIG}/Architecture: ${ARCHDPKG}/" <control/control >control/control.arch
	mv control/control.arch control/control

	if test -n "$MAINTORIG"
	then
		sed "s/Maintainer: ${MAINTORIG}/Maintainer: ${MAINTAINER}/" <control/control >control/control.maint
		mv control/control.maint control/control
	fi
fi

if test -f control/md5sums
then
	(
		set -e
		cd data 
		find * -type f -print0 | xargs -r0 md5sum	
	) > control/md5sums
fi

if $MAKE_DEB
then
	(
		set -e
		cd control
		tar --owner=0 --group=0 --create --xz --file ../control.tar.xz ./*
	)

	(
		set -e
		cd data
		tar --owner=0 --group=0 --create --xz --file ../data.tar.xz ./* 
	)

	PKGNAME="${PACKAGE}${USCORE}${VERSION}${USCORE}${ARCHDPKG}.deb"

	rm -f "${PKGNAME}" 

	ar r "${PKGNAME}" debian-binary control.tar.xz data.tar.xz

	ls -ld "${PKGNAME}"
fi

if $MAKE_RPM
then
	RELEASE=1.$ID.$VERSION_ID

	for d in `grep Release < control/values`
	do
		if test -n "$d"
		then
			RELEASE="$d"
		fi
	done

	cat > rpm.spec <<EOF
Summary: PowerShell is an automation and configuration management platform.
Name: $PACKAGE
Version: $VERSION
Release: $RELEASE
Group: shells
License: MIT LICENSE
Vendor: Microsoft Corporation
URL: https://microsoft.com/powershell
Packager: $MAINTAINER
Autoreq: 0
AutoReqProv: no
Prefix: /

%description
PowerShell is an automation and configuration management platform.
It consists of a cross-platform command-line shell and associated scripting language.

%files
%defattr(-,root,root)
/opt/microsoft/powershell/7
/usr/bin/pwsh
/usr/local/share/man/man1/pwsh.1.gz

%clean
EOF

	PWD=`pwd`

	rm -rf "$PWD/data/usr/lib/.build-id"

	if rmdir "$PWD/data/usr/lib"
	then
		:
	fi

	rpmbuild --buildroot "$PWD/data" --define "_rpmdir $PWD/rpms" -bb "$PWD/rpm.spec" --define "_build_id_links none" 

	find rpms -type f -name "*.rpm" | while read N
	do
		mv "$N" .
		basename "$N"
	done
fi
