# MSIX Packaging for Kiwix Desktop

This directory contains the files and scripts needed to build an MSIX package for Kiwix Desktop that can be distributed through the Microsoft Store.

## Files Overview

- `Package.appxmanifest` - MSIX package manifest with application metadata
- `scripts/build-msix.ps1` - PowerShell script to build the MSIX package
- `scripts/create-msix-assets.ps1` - Script to prepare icon assets
- `.github/workflows/msix.yml` - GitHub Actions workflow for automated building

## Prerequisites

To build MSIX packages, you need:

1. **Windows 10/11 SDK** - Contains MakeAppx.exe and other packaging tools
2. **Windows 10 version 1809 (build 17763) or later** - For modern MSIX support
3. **Code signing certificate** (for distribution) - Required for Microsoft Store

## Local Development

### Building Manually

1. Build the Qt application as usual:
   ```cmd
   qmake PREFIX=%cd%\BUILD_win-amd64\INSTALL
   nmake release-all
   ```

2. Create MSIX assets:
   ```powershell
   .\scripts\create-msix-assets.ps1
   ```

3. Build the MSIX package:
   ```powershell
   .\scripts\build-msix.ps1 -BuildPath "." -OutputPath "kiwix-desktop.msix"
   ```

### Testing the Package

To test the MSIX package locally:

```powershell
# Install the package (developer mode required)
Add-AppxPackage -Path "kiwix-desktop.msix"

# Test the application
# Look for "Kiwix" in the Start menu

# Uninstall when done testing
Get-AppxPackage "*Kiwix*" | Remove-AppxPackage
```

## GitHub Actions CI/CD

The workflow `.github/workflows/msix.yml` automatically:

1. Builds the Windows executable using the existing CI setup
2. Creates the MSIX package using our build script
3. Signs the package (if signing secrets are configured)
4. Uploads the package as a build artifact
5. Attaches the package to GitHub releases

### Required Secrets (for signing)

To enable code signing, add these secrets to your GitHub repository:

- `SIGNING_CERTIFICATE` - Base64 encoded .pfx certificate file
- `SIGNING_PASSWORD` - Password for the certificate

```powershell
# Convert certificate to base64 for GitHub secrets
$certBytes = [IO.File]::ReadAllBytes("your-certificate.pfx")
[Convert]::ToBase64String($certBytes) | Set-Clipboard
```

## Microsoft Store Submission

### Before Store Submission

1. **Get a Microsoft Store developer account** ($19 one-time fee for individuals)
2. **Obtain a trusted code signing certificate** from a CA like DigiCert, Sectigo, etc.
3. **Create high-quality icon assets** following Microsoft Store guidelines
4. **Test thoroughly** on different Windows versions and devices

### Store Guidelines Compliance

The package is configured to meet basic Microsoft Store requirements:

- ✅ Uses restricted capabilities appropriately
- ✅ Declares file type associations (.zim files)
- ✅ Includes proper metadata and descriptions
- ✅ Follows naming conventions
- ⚠️ **Icon assets need professional design** for store approval
- ⚠️ **Needs thorough testing** on various Windows configurations

### Submission Process

1. **Prepare store listing** with screenshots, descriptions, and metadata
2. **Upload the signed MSIX package** to Partner Center
3. **Complete certification requirements** (privacy policy, age ratings, etc.)
4. **Submit for review** - Microsoft will test the package
5. **Address any certification issues** if found
6. **Publish** once approved

## Package Details

### Application Identity

- **Name**: KiwixFoundation.Kiwix
- **Publisher**: CN=Kiwix Foundation (will need to match your code signing certificate)
- **Version**: Automatically derived from Git tags (format: x.y.z.0)

### Capabilities

The package requests these Windows capabilities:

- `internetClient` - For downloading content and updates
- `privateNetworkClientServer` - For local HTTP server functionality
- `runFullTrust` - Full system access (required for Qt applications)
- `removableStorage` - Access to USB drives and external storage
- `documentsLibrary` - Access to user's document folders

### File Associations

- Registers `.zim` file type association
- Supports `kiwix://` protocol URLs

## Troubleshooting

### Common Issues

**"MakeAppx.exe not found"**
- Install Windows 10/11 SDK from Microsoft
- Update the path in build script if installed in non-standard location

**"App won't start after installation"**
- Check that all Qt dependencies are included in the package
- Verify VC++ redistributables are present
- Test with Windows Application Verifier

**"Package signature is invalid"**
- Ensure certificate is trusted on the target system
- For development, enable Developer Mode in Windows Settings
- Use self-signed certificates only for testing

**"File type association not working"**
- Check that the manifest file associations are correct
- Verify the application handles command-line arguments for opened files

### Debugging

Enable MSIX package debugging:

```powershell
# Get package details
Get-AppxPackage "*Kiwix*"

# View package manifest
Get-AppxPackageManifest -Package "KiwixFoundation.Kiwix_*"

# Check event logs
Get-WinEvent -LogName "Microsoft-Windows-AppxPackaging/Operational" | Where-Object {$_.Message -like "*Kiwix*"}
```

## Future Improvements

- [ ] Professional icon design for all required asset sizes
- [ ] Automated screenshot generation for store listing
- [ ] Delta package updates for smaller download sizes
- [ ] Microsoft Store Connect API integration
- [ ] Telemetry and crash reporting for store version
- [ ] In-app purchase integration (if applicable)

## References

- [Microsoft Store Policies](https://docs.microsoft.com/en-us/legal/windows/agreements/store-policies)
- [MSIX Packaging Documentation](https://docs.microsoft.com/en-us/windows/msix/)
- [App packaging with Visual Studio](https://docs.microsoft.com/en-us/windows/msix/package/packaging-uwp-apps)
- [Microsoft Store submission process](https://docs.microsoft.com/en-us/windows/uwp/publish/app-submissions)
