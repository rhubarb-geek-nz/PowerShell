# PowerShell on Windows

This script uses WiX to package the contents of the official zips as MSI.

* The contents of the zip are installed in %ProgramFiles%\PowerShell\7.
* The PATH environment variable is adjusted to include the directory.
* A program short cut is created.

This uses a dotnet tool [rhubarb-geek-nz.dir2wxs](https://github.com/rhubarb-geek-nz/dir2wxs) to create the directory structure in the WiX input file.
