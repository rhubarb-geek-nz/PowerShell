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

for d in $( . /etc/os-release ; echo $ID $ID_LIKE )
do
	echo $d
done | grep '^ubuntu$'

LIBICU=libicu74
LIBSSL=libssl3t64

dpkg -l "$LIBICU"
dpkg -l "$LIBSSL"

umask 022

if test -z "$MAINTAINER"
then
	git config user.email > /dev/null

	MAINTAINER="$(git config user.email)"
fi

test -n "$MAINTAINER"

clean()
{
	rm -rf data.tar* control.tar* debian-binary control
}

trap clean 0

for F in $@
do
	test -f "$F"

	ar t "$F" | while read N
	do
		case "$N" in
			debian-binary | control.tar* | data.tar* )
				ar x "$F" "$N"
				;;
			* )
				;;
		esac
	done

	ls -ld control.tar*

	mkdir control

	(
		set -e
		cd control

		for C in ../control.tar*
		do
			case "$C" in
				../control.tar.gz )
					tar xfz "$C"
					;;

				../control.tar.xz )
					tar xfJ "$C"
					;;

				../control.tar )
					tar xf "$C"
					;;
				* )
					;;
			esac
		done

		cp control control.old

		(
			while read A
			do
				DONE=false
				case "$A" in
					Version:* )
						echo $A | while read B C
						do
							echo $B $( echo $C | sed "s/.deb/.ubuntu/" )
						done
						;;
					Maintainer:* )
						echo "Maintainer:" "$MAINTAINER"
						;;
					Depends:* )
						echo "$A" | (
							DEPS=
							while read B C
							do
								IFS=,
								for D in $C
								do
									D=$(
										IFS=' '
										for E in $D
										do
											if test -n "$E"
											then
												echo "$E"
											fi
										done
									)

									case "$D" in
										libicu72* )
											D="$LIBICU"
											;;
										libssl3* )
											D="$LIBSSL"
											;;
										* )
											;;
									esac

									if test -z "$DEPS"
									then
										DEPS="$D"
									else
										DEPS="$DEPS, $D"
									fi
								done
							done

							echo "Depends: $DEPS"
						)

						DONE=true
						;;
					*)
						echo "$A"
						;;
				esac
				if $DONE
				then
					break
				fi
			done
			cat
		) < control.old > control

		if diff control.old control
		then
			echo "no changes" >&2

			false
		fi

		rm control.old

		for C in ../control.tar*
		do
			case "$C" in
				../control.tar.gz )
					tar --owner=0 --group=0 --create --gzip --file "$C" ./*
					;;

				../control.tar.xz )
					tar --owner=0 --group=0 --create --xz --file "$C" ./*
					;;

				../control.tar )
					tar --owner=0 --group=0 --create --file "$C" ./*
					;;
				* )
					;;
			esac
		done
	)

	PACKAGE=
	VERSION=
	ARCHITECTURE=

	while read A B C
	do
		case "$A" in
			Package: )
				PACKAGE="$B"
				;;
			Version: )
				VERSION="$B"
				;;
			Architecture: )
				ARCHITECTURE="$B"
				;;
			* )
				;;
		esac
	done < control/control

	rm -rf control

	test -n "$PACKAGE"
	test -n "$VERSION"
	test -n "$ARCHITECTURE"

	U=_

	O="$PACKAGE$U$VERSION$U$ARCHITECTURE.deb"

	rm -rf "$O"

	ar r "$O" debian-binary control.tar* data.tar.*
done
