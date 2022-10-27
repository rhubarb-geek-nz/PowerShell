/**************************************************************************
 *
 *  Copyright 2022, Roger Brown
 *
 *  This file is part of rhubarb pi.
 *
 *  This program is free software: you can redistribute it and/or modify it
 *  under the terms of the GNU General Public License as published by the
 *  Free Software Foundation, either version 3 of the License, or (at your
 *  option) any later version.
 * 
 *  This program is distributed in the hope that it will be useful, but WITHOUT
 *  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 *  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
 *  more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>
 *
 */

/*
 * $Id: launcher.c 189 2022-09-17 23:43:21Z rhubarb-geek-nz $
 */

#include <stdlib.h>
#include <unistd.h>

int main(int argc,char **argv)
{
	char *args[]={
		"/usr/bin/open",
		"/usr/local/bin/pwsh",
		NULL
	};

	execv(args[0],args);

	return 1;
}
