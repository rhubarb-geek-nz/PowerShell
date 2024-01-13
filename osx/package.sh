#!/bin/sh -e
#
#  Copyright 2024, Roger Brown
#
#  This file is part of rhubarbi-geek-nz/PowerShell.
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

VERSION=7.2.18
ARCH=arm64
PKGNAME=powershell
LAUNCHER=Applications/PowerShell.app/Contents/MacOS/PowerShell.sh
IDENTIFIER=com.microsoft.powershell
FULLNAME="$PKGNAME-$VERSION-osx-$ARCH.pkg"

trap "rm -rf data root distribution.xml $PKGNAME.pkg $FULLNAME.original" 0

curl --silent --fail --location --output "$FULLNAME.original" "https://github.com/PowerShell/PowerShell/releases/download/v$VERSION/$FULLNAME"

mkdir data root

(
	set -e

	cd data

	xar -xf "../$FULLNAME.original"
)

rm "$FULLNAME.original"

(
	set -e

	cd root

	gunzip < "../data/$PKGNAME-$VERSION.pkg/Payload" | cpio -i
)

cc launcher.c -Wall -Werror -arch arm64 -o "root/$LAUNCHER"

strip "root/$LAUNCHER"

pkgbuild \
	--identifier $IDENTIFIER \
	--version "$VERSION" \
	--root root \
	--install-location / \
	--sign "Developer ID Installer: $APPLE_DEVELOPER" \
	"$PKGNAME.pkg"

cat > distribution.xml <<EOF
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="1">
    <pkg-ref id="$IDENTIFIER"/>
    <options customize="never" require-scripts="false" hostArchitectures="arm64"/>
    <choices-outline>
        <line choice="default">
            <line choice="$IDENTIFIER"/>
        </line>
    </choices-outline>
    <choice id="default"/>
    <choice id="$IDENTIFIER" visible="false">
        <pkg-ref id="$IDENTIFIER"/>
    </choice>
    <pkg-ref id="$IDENTIFIER" version="$VERSION" onConclusion="none">$PKGNAME.pkg</pkg-ref>
    <title>PowerShell - $VERSION</title>
</installer-gui-script>
EOF

productbuild \
	--distribution ./distribution.xml \
	--product requirements.plist \
	--package-path . \
	"$FULLNAME" \
	--sign "Developer ID Installer: $APPLE_DEVELOPER"
