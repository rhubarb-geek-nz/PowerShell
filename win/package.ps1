#!/usr/bin/env pwsh
#
#  Copyright 2023, Roger Brown
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
# $Id: package.ps1 250 2023-04-15 06:28:32Z rhubarb-geek-nz $
#

$POWERSHELL_VERSION = "7.3.10"
$ZIPFILE = "PowerShell-$POWERSHELL_VERSION-win-arm64.zip"
$URL = "https://github.com/PowerShell/PowerShell/releases/download/v$POWERSHELL_VERSION/$ZIPFILE"
$SRCDIR = "src"
$DIR2WXS = "dir2wxs\bin\Release\net6.0\dir2wxs.dll"

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

trap
{
	throw $PSItem
}

If(!(test-path -PathType container "$SRCDIR"))
{
	$Null = New-Item -ItemType Directory -Path "$SRCDIR"

	Write-Host "$URL"

	Invoke-WebRequest -Uri "$URL" -OutFile "$ZIPFILE"

	Expand-Archive -LiteralPath "$ZIPFILE" -DestinationPath "$SRCDIR"
}

@'
<?xml version="1.0" encoding="UTF-8"?>
<Wix xmlns="http://schemas.microsoft.com/wix/2006/wi">
  <Product Id="*" Name="PowerShell 7 ARM64" Language="1033" Version="7.3.10.0" Manufacturer="Microsoft Corporation" UpgradeCode="31AB5147-9A97-4452-8443-D9709F0516E1">
    <Package InstallerVersion="500" Compressed="yes" InstallScope="perMachine" Platform="arm64" Description="PowerShell 7.3.10 ARM64" Comments="PowerShell 7.3.10 ARM64" />
    <MediaTemplate EmbedCab="yes" />
    <Feature Id="ProductFeature" Title="setup" Level="1">
      <ComponentGroupRef Id="ProductComponents" />
    </Feature>
    <Upgrade Id="{31AB5147-9A97-4452-8443-D9709F0516E1}">
      <UpgradeVersion Maximum="7.3.10.0" Property="OLDPRODUCTFOUND" OnlyDetect="no" IncludeMinimum="yes" IncludeMaximum="no" />
    </Upgrade>
    <InstallExecuteSequence>
      <RemoveExistingProducts After="InstallInitialize" />
      <WriteEnvironmentStrings/>
    </InstallExecuteSequence>
    <DirectoryRef Id="INSTALLDIR">
      <Component Id ="setEnviroment" Guid="{3517A291-40CB-4770-B134-D9E100AC2699}" Win64="yes">
        <CreateFolder />
        <Environment Id="PATH" Action="set" Name="PATH" Part="last" Permanent="no" System="yes" Value="[INSTALLDIR]" />
       </Component>
    </DirectoryRef>
    <Feature Id="PathFeature" Title="PATH" Level="1" Absent="disallow" AllowAdvertise="no" Display="hidden" >
      <ComponentRef Id="setEnviroment"/>
      <ComponentRef Id="ApplicationShortcut" />
      <ComponentRef Id="pwsh.exe" />
    </Feature>
    <DirectoryRef Id="ApplicationProgramsFolder">
      <Component Id="ApplicationShortcut" Guid="{D4A0639B-7BDD-4912-9489-FB8D227D507C}">
        <Shortcut Id="ApplicationStartMenuShortcut"
                  Name="PowerShell 7 (arm64)"
                  Description="PowerShell 7.3.10 for ARM64"
                  Target="[#pwsh.exe]"
                  Arguments="-WorkingDirectory ~"
                  WorkingDirectory="INSTALLDIR"/>
        <RemoveFolder Id="CleanUpShortCut" Directory="ApplicationProgramsFolder" On="uninstall"/>
        <RegistryValue Root="HKCU" Key="Software\Microsoft\PowerShell7" Name="installed" Type="integer" Value="1" KeyPath="yes"/>
      </Component>
    </DirectoryRef>
  </Product>
  <Fragment>
    <Directory Id="TARGETDIR" Name="SourceDir">
      <Directory Id="ProgramFiles64Folder">
        <Directory Id="INSTALLPRODUCT" Name="PowerShell">
          <Directory Id="INSTALLDIR" Name="7" />
        </Directory>
      </Directory>
      <Directory Id="ProgramMenuFolder" Name="ProgramMenuFolder" >
        <Directory Id="ApplicationProgramsFolder" Name="PowerShell 7"/>
      </Directory>
    </Directory>
  </Fragment>
  <Fragment>
    <ComponentGroup Id="ProductComponents">
      <Component Id="pwsh.exe" Guid="*" Directory="INSTALLDIR" Win64="yes">
        <File Id="pwsh.exe" KeyPath="yes" Source="src\pwsh.exe" />
      </Component>
    </ComponentGroup>
  </Fragment>
</Wix>
'@ | dotnet "$DIR2WXS" -o "PowerShell.wxs" -s "$SRCDIR"

If ( $LastExitCode -ne 0 )
{
	Exit $LastExitCode
}

& "$ENV:WIX/bin/candle.exe" -nologo "PowerShell.wxs" -ext WixUtilExtension 

If ( $LastExitCode -ne 0 )
{
	Exit $LastExitCode
}

& "$ENV:WIX/bin/light.exe" -sw1076 -nologo -cultures:null -out "PowerShell-$POWERSHELL_VERSION-win-arm64.msi" "PowerShell.wixobj" -ext WixUtilExtension

If ( $LastExitCode -ne 0 )
{
	Exit $LastExitCode
}
