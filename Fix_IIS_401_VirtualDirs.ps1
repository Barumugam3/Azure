# Consolidated PowerShell Script to Fix 401.2 Unauthorized for Virtual Directories
# Environment: IIS with ~300 Virtual Directories, 4 App Pools, Non-Clustered Setup

Import-Module WebAdministration

# === CONFIGURE YOUR APPLICATION POOLS HERE ===
$appPools = @("AppPool1", "AppPool2", "AppPool3", "AppPool4")
$siteName = "Default Web Site"  # Change as needed

# === Function: Assign NTFS Permissions to AppPool Identity ===
function Grant-AppPoolPermission($appPool, $physicalPath) {
    $user = "IIS AppPool\\$appPool"
    $acl = Get-Acl $physicalPath
    $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($user, "ReadAndExecute", "ContainerInherit,ObjectInherit", "None", "Allow")
    $acl.SetAccessRule($accessRule)
    try {
        Set-Acl -Path $physicalPath -AclObject $acl
        Write-Host "Granted ReadAndExecute to $user on $physicalPath"
    } catch {
        Write-Warning "Failed to set ACL on $physicalPath. Error: $_"
    }
}

# === Step 1: Iterate Through AppPools & Apply Permissions to VDs ===
foreach ($appPool in $appPools) {
    Write-Host "Processing App Pool: $appPool"

    # Get virtual directories assigned to this app pool
    $vDirs = Get-WebVirtualDirectory -Site $siteName

    foreach ($vd in $vDirs) {
        $physicalPath = $vd.physicalPath
        Grant-AppPoolPermission -appPool $appPool -physicalPath $physicalPath
    }
}

# === Step 2: Force Inheritance of Authentication Settings ===
Write-Host "`nClearing authentication overrides in all virtual directories..."
Get-WebVirtualDirectory -Site $siteName | ForEach-Object {
    $vdPath = "IIS:\\Sites\\$siteName$($_.Path)"
    Clear-WebConfiguration -Filter /system.webServer/security/authentication -PSPath $vdPath
}

# === Step 3: Scan for Web.config Files That Block Anonymous Users ===
Write-Host "`nScanning for web.config files with deny users=\"?\"..."
Get-ChildItem -Path "C:\\inetpub\\wwwroot" -Recurse -Filter web.config |
    Select-String "<deny users=\\"\\?\\".*?>" |
    ForEach-Object { Write-Warning "Deny rule found in: $($_.Path)" }

Write-Host "`nCompleted. Review warnings and restart IIS if needed."
