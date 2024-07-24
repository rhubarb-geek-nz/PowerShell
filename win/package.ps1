#!/usr/bin/env pwsh
#
#  Copyright 2023, Roger Brown
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

param(
	$POWERSHELL_VERSION = 'latest'
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

trap
{
	throw $PSItem
}

if ( $POWERSHELL_VERSION -eq 'latest' )
{
	$POWERSHELL_VERSION = ((Invoke-WebRequest -Uri 'https://api.github.com/repos/PowerShell/PowerShell/releases/latest').Content | ConvertFrom-JSON -AsHashTable)['tag_name']
	if ($POWERSHELL_VERSION[0] -eq 'v')
	{
		$POWERSHELL_VERSION = $POWERSHELL_VERSION.Substring(1)
	}
}

$ZIPFILE = "PowerShell-$POWERSHELL_VERSION-win-arm64.zip"
$URL = "https://github.com/PowerShell/PowerShell/releases/download/v$POWERSHELL_VERSION/$ZIPFILE"
$SRCDIR = "src-$POWERSHELL_VERSION"

dotnet tool restore

If ( $LastExitCode -ne 0 )
{
	Exit $LastExitCode
}

If (Test-Path -LiteralPath $SRCDIR -PathType container)
{
	Remove-Item -LiteralPath $SRCDIR -Recurse
}

If ( -not (Test-Path -LiteralPath $ZIPFILE ))
{
	Write-Host "$URL"

	Invoke-WebRequest -Uri $URL -OutFile $ZIPFILE
}

	Expand-Archive -LiteralPath $ZIPFILE -DestinationPath $SRCDIR

try
{
@'
<?xml version="1.0" encoding="UTF-8"?>
<Wix xmlns="http://schemas.microsoft.com/wix/2006/wi">
  <Product Id="*" Name="PowerShell 7 ARM64" Language="1033" Version="$(POWERSHELL_VERSION).0" Manufacturer="Microsoft Corporation" UpgradeCode="1D00683B-0F84-4DB8-A64F-2F98AD42FE06">
    <Package InstallerVersion="500" Compressed="yes" InstallScope="perMachine" Platform="arm64" Description="PowerShell $(POWERSHELL_VERSION) ARM64" Comments="PowerShell $(POWERSHELL_VERSION) ARM64" />
    <MediaTemplate EmbedCab="yes" />
    <Feature Id="ProductFeature" Title="setup" Level="1">
      <ComponentGroupRef Id="ProductComponents" />
    </Feature>
    <Upgrade Id="{1D00683B-0F84-4DB8-A64F-2F98AD42FE06}">
      <UpgradeVersion Maximum="$(POWERSHELL_VERSION).0" Property="OLDPRODUCTFOUND" OnlyDetect="no" IncludeMinimum="yes" IncludeMaximum="no" />
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
                  Description="PowerShell $(POWERSHELL_VERSION) for ARM64"
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
        <File Id="pwsh.exe" KeyPath="yes" Source="$(SRCDIR)\pwsh.exe" />
      </Component>
    </ComponentGroup>
  </Fragment>
</Wix>
'@.Replace('$(POWERSHELL_VERSION)',$POWERSHELL_VERSION).Replace('$(SRCDIR)',$SRCDIR) | dotnet dir2wxs -o "PowerShell.wxs" -s "$SRCDIR"

	If ( $LastExitCode -ne 0 )
	{
		Exit $LastExitCode
	}

	& "$ENV:WIX/bin/candle.exe" -nologo "PowerShell.wxs" -ext WixUtilExtension 

	If ( $LastExitCode -ne 0 )
	{
		Exit $LastExitCode
	}

	& "$ENV:WIX/bin/light.exe" -sw1076 -nologo -cultures:null -out "PowerShell-$POWERSHELL_VERSION-win-arm64.msi" 'PowerShell.wixobj' -ext WixUtilExtension

	If ( $LastExitCode -ne 0 )
	{
		Exit $LastExitCode
	}

	$codeSignCertificate = Get-ChildItem -path Cert:\ -Recurse -CodeSigningCert | Where-Object {$_.Thumbprint -eq '601A8B683F791E51F647D34AD102C38DA4DDB65F'}

	if ( -not $codeSignCertificate )
	{
		throw 'Codesign certificate not found'
	}

	Set-AuthenticodeSignature -Certificate $codeSignCertificate -TimestampServer 'http://timestamp.digicert.com' -HashAlgorithm SHA256 -FilePath "PowerShell-$POWERSHELL_VERSION-win-arm64.msi"
}
finally
{
	Remove-Item -LiteralPath $SRCDIR -Recurse
}
