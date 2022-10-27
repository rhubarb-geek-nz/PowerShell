# PowerShell on macOS with ARM64

Although there is already an installer for PowerShell on ARM64 it currently requires Rosetta to be installed. This works around that.

## Installer

This uses a requirements.xml to specify ARM64 platform only as a requirement.

```
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
        <key>arch</key>
        <array>
                <string>arm64</string>
        </array>
</dict>
</plist>
```

## Installer Scripts

The current installer requires Rosetta due to scripts that run during installation. This removes that dependency.

## Application Icon

The current application launcher requires Rosetta as it is a shell script. This is replaced by a compiled ARM64 executable.

```
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
```
