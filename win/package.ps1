#!/usr/bin/env pwsh
#
#  Copyright 2026, Roger Brown
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
	$CertificateThumbprint = '601A8B683F791E51F647D34AD102C38DA4DDB65F'
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

trap
{
	throw $PSItem
}

$CompanyName = 'Microsoft Corporation'
$ProductName = 'PowerShell'
$PowerShellVersion = '7.7.0'

dotnet tool restore

If ( $LastExitCode -ne 0 )
{
	Exit $LastExitCode
}

$codeSignCertificate = Get-ChildItem -path Cert:\ -Recurse -CodeSigningCert | Where-Object { $_.Thumbprint -eq $CertificateThumbprint }

if ($codeSignCertificate.Count -ne 1)
{
	Write-Error "Error with certificate - $CertificateThumbprint"
}

$PowerShellMsiComments = "$ProductName $PowerShellVersion-preview.2"

$ArchList = @(
	@{
		Arch = 'x86'
		UpgradeCode = '1D00683B-0F84-4DB8-A64F-2F98AD42FE06'
		Win64 = 'no'
		Platform = 'x86'
		ProgramFilesFolder = 'ProgramFilesFolder'
		InstallerVersion = '200'
		EnvironmentGuid = '9F718501-562E-4C41-97E0-09E93D6698EA'
		ApplicationShortcutGuid = '2B6CE39E-287B-4B1F-AE34-9AAAB68EF150'
	},
	@{
		Arch = 'x64'
		UpgradeCode = '31AB5147-9A97-4452-8443-D9709F0516E1'
		Win64 = 'yes'
		Platform = 'x64'
		ProgramFilesFolder = 'ProgramFiles64Folder'
		InstallerVersion = '200'
		EnvironmentGuid = '8AC5A84A-6989-4023-BBC9-2CF289952E35'
		ApplicationShortcutGuid = 'E03DA96F-2A57-49A2-BB95-C1B73768CD17'
	},
	@{
		Arch = 'arm64'
		UpgradeCode = '75C68AB2-09D8-46B8-B697-D829BDD4C94F'
		Win64 = 'yes'
		Platform = 'arm64'
		ProgramFilesFolder = 'ProgramFiles64Folder'
		InstallerVersion = '500'
		EnvironmentGuid = '68AED3CC-F112-4400-8839-6C029532ECDD'
		ApplicationShortcutGuid = '2E423858-944E-449E-9A78-3506E2964740'
	}
)

foreach ($Arch in $ArchList)
{
	$MsiStem = "PowerShell-$PowerShellVersion-preview.2-win-$($Arch.Arch)"
	$ZipName = "$MsiStem.zip"

	$Url = "https://github.com/PowerShell/PowerShell/releases/download/v$PowerShellVersion-preview.2/$ZipName"

	$PublishDir = "$MsiStem.publish"

	if (-not (Test-Path -LiteralPath $PublishDir))
	{
		If ( -not (Test-Path -LiteralPath $ZipName ))
		{
			Write-Host "$Url"

			Invoke-WebRequest -Uri $Url -OutFile $ZipName
		}

		Expand-Archive -LiteralPath $ZipName -DestinationPath $PublishDir
	}

@'
<?xml version="1.0" encoding="UTF-8"?>
<Wix xmlns="http://schemas.microsoft.com/wix/2006/wi">
  <Product Id="*" Name="$(var.ProductName) ($(var.Platform))" Language="1033" Version="$(var.PowerShellVersion).0" Manufacturer="$(var.CompanyName)" UpgradeCode="$(var.UpgradeCode)">
    <Package InstallerVersion="$(var.InstallerVersion)" Compressed="yes" InstallScope="perMachine" Platform="$(var.Platform)" Description="$(var.ProductName) $(var.PowerShellVersion) $(var.Platform)" Comments="$(var.PowerShellMsiComments)" />
    <MediaTemplate EmbedCab="yes" />
    <Feature Id="ProductFeature" Title="setup" Level="1">
      <ComponentGroupRef Id="ProductComponents" />
    </Feature>
    <Upgrade Id="{$(var.UpgradeCode)}">
      <UpgradeVersion Maximum="$(var.PowerShellVersion).0" Property="OLDPRODUCTFOUND" OnlyDetect="no" IncludeMinimum="yes" IncludeMaximum="no" />
    </Upgrade>
    <InstallExecuteSequence>
      <RemoveExistingProducts After="InstallInitialize" />
      <WriteEnvironmentStrings/>
    </InstallExecuteSequence>
    <DirectoryRef Id="INSTALLDIR">
      <Component Id ="setEnviroment" Guid="$(var.EnvironmentGuid)" Win64="$(var.Win64)">
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
      <Component Id="ApplicationShortcut" Guid="$(var.ApplicationShortcutGuid)">
        <Shortcut Id="ApplicationStartMenuShortcut"
                  Name="PowerShell 7 ($(var.Platform))"
                  Description="PowerShell $(var.PowerShellVersion) for $(var.Platform)"
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
      <Directory Id="$(var.ProgramFilesFolder)">
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
      <Component Id="pwsh.exe" Guid="*" Directory="INSTALLDIR" Win64="$(var.Win64)">
        <File Id="pwsh.exe" KeyPath="yes" Source="PublishDir\pwsh.exe" />
      </Component>
    </ComponentGroup>
  </Fragment>
</Wix>
'@.Replace('PublishDir',$PublishDir) | dotnet dir2wxs -o "$MsiStem.wxs" -s $PublishDir

	If ( $LastExitCode -ne 0 )
	{
		Exit $LastExitCode
	}

	& "$ENV:WIX\bin\candle.exe" `
			"$MsiStem.wxs" `
			-nologo `
			-ext WixUtilExtension `
			"-dWin64=$($Arch.Win64)" `
			"-dPlatform=$($Arch.Platform)" `
			"-dProgramFilesFolder=$($Arch.ProgramFilesFolder)" `
			"-dUpgradeCode=$($Arch.UpgradeCode)" `
			"-dInstallerVersion=$($Arch.InstallerVersion)" `
			"-dEnvironmentGuid=$($Arch.EnvironmentGuid)" `
			"-dApplicationShortcutGuid=$($Arch.ApplicationShortcutGuid)" `
			"-dCompanyName=$CompanyName" `
			"-dProductName=$ProductName" `
			"-dPowerShellVersion=$PowerShellVersion" `
			"-dPowerShellMsiComments=$PowerShellMsiComments"

	If ( $LastExitCode -ne 0 )
	{
		Exit $LastExitCode
	}

	& "$ENV:WIX\bin\light.exe" -sw1076 -nologo -cultures:null -out "$MsiStem.msi" "$MsiStem.wixobj" -ext WixUtilExtension

	If ( $LastExitCode -ne 0 )
	{
		Exit $LastExitCode
	}

	$null = Set-AuthenticodeSignature -FilePath "$MsiStem.msi" -HashAlgorithm 'SHA256' -Certificate $codeSignCertificate -TimestampServer 'http://timestamp.digicert.com'

	foreach ($WixExt in 'wxs','wixobj','wixpdb')
	{
		Remove-Item "$MsiStem.$WixExt"
	}

	Remove-Item $PublishDir -Recurse
	Remove-Item $ZipName
}
