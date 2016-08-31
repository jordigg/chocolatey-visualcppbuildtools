# Parse input argument string into a hashtable
# Format: /AdminFile:file location /Features:WebTools,Win8SDK /ProductKey:AB-D1
function Parse-Parameters ($s)
{
    $parameters = @{ }

    if (!$s)
    {
        Write-Debug "No package parameters."
        return $parameters
    }

    Write-Debug "Package parameters: $s"
    $s = ' ' + $s
    [String[]] $kvpPrefix = @(" --")
    $kvpDelimiter = ' '

    $kvps = $s.Split($kvpPrefix, [System.StringSplitOptions]::RemoveEmptyEntries)
    foreach ($kvp in $kvps)
    {
        Write-Debug "Package parameter kvp: $kvp"
        $delimiterIndex = $kvp.IndexOf($kvpDelimiter)
        if (($delimiterIndex -le 0) -or ($delimiterIndex -ge ($kvp.Length - 1))) { continue }

        $key = $kvp.Substring(0, $delimiterIndex).Trim().ToLower()
        if ($key -eq '') { continue }
        $value = $kvp.Substring($delimiterIndex + 1).Trim()

        Write-Debug "Package parameter: key=$key, value=$value"
        $parameters.Add($key, $value)
    }

    return $parameters
}

# Generates customizations file. Returns its path
function Generate-Admin-File($parameters, $defaultAdminFile)
{
    $adminFile = $parameters['AdminFile']
    $features = $parameters['Features']
    if (!$adminFile -and !$features)
    {
        return $null
    }

    $localAdminFile = (Join-Path $env:temp 'AdminDeployment.xml')
    if (Test-Path $localAdminFile)
    {
        Remove-Item $localAdminFile
    }

    if ($adminFile)
    {
        if (Test-Path $adminFile)
        {
            Copy-Item $adminFile $localAdminFile -force
        }
        else
        {
            if (($adminFile -as [System.URI]).AbsoluteURI -ne $null)
            {
                Get-ChocolateyWebFile 'adminFile' $localAdminFile $adminFile
            }
            else
            {
                throw 'Invalid AdminFile setting.'
            }
        }
    }
    elseif ($features)
    {
        Copy-Item $defaultAdminFile $localAdminFile -force
    }

    return $localAdminFile
}

# Turns on features in the customizations file
function Update-Admin-File($parameters, $adminFile)
{
    if (!$adminFile) { return }
    $s = $parameters['Features']
    if (!$s) { return }

    $features = $s.Split(',')
    [xml]$xml = Get-Content $adminFile

    foreach ($feature in $features)
    {
        $node = $xml.DocumentElement.SelectableItemCustomizations.ChildNodes | ? {$_.Id -eq "$feature"}
        if ($node -ne $null)
        {
            $node.Selected = "yes"
        }
    }
    $xml.Save($adminFile)
}

function Generate-Install-Arguments-String($parameters, $adminFile)
{
    $s = "/Quiet /NoRestart /Log $env:temp\vs.log"

    if ($adminFile)
    {
        $s = $s + " /AdminFile $adminFile"
    }

    $pk = $parameters['ProductKey']
    if ($pk)
    {
        $s = $s + " /ProductKey $pk"
    }

    return $s
}

function Install-VS {
<#
.SYNOPSIS
Installs Microsoft Visual C++ Build Tools

.DESCRIPTION
Installs Microsoft Visual C++ Build Tools with ability to specify additional features.

.PARAMETER PackageName
The name of the Microsoft Visual C++ Build Tools package - this is arbitrary.
It's recommended you call it the same as your nuget package id.

.PARAMETER Url
This is the url to download the VS web installer.

.EXAMPLE
Install-VS 'VisualCppBuildTools' 'http://download.microsoft.com/download/5/f/7/5f7acaeb-8363-451f-9425-68a90f98b238/visualcppbuildtools_full.exe'

.OUTPUTS
None

.NOTES
This helper reduces the number of lines one would have to write to download and install Microsoft Visual C++ Build Tools.
This method has no error handling built into it.

.LINK
Install-ChocolateyPackage
#>
param(
  [string] $packageName,
  [string] $url,
  [string] $exeName,
  [string] $checksum
)
        Write-Debug "Running 'Install-VS' for $packageName with url:`'$url`'";
 
    $installerType = 'exe'
    $validExitCodes = @(
        0, # success
        3010, # success, restart required
        2147781575 # pending restart required
    )
 
    $defaultAdminFile = (Join-Path $PSScriptRoot 'AdminDeployment.xml')
    Write-Debug "Default AdminFile: $defaultAdminFile"
 
    $packageParameters = Parse-Parameters $env:chocolateyPackageParameters
    if ($packageParameters.Length -gt 0) { Write-Output $packageParameters }
 
    $adminFile = Generate-Admin-File $packageParameters $defaultAdminFile
    Write-Debug "AdminFile: $adminFile"
 
    Update-Admin-File $packageParameters $adminFile
 
    $silentArgs = Generate-Install-Arguments-String $packageParameters $adminFile
    
    Write-Output "Install-ChocolateyPackage $packageName $installerType $silentArgs $url -validExitCodes $validExitCodes"
    Install-ChocolateyPackage $packageName $installerType $silentArgs $url -validExitCodes $validExitCodes -Checksum $checksum -ChecksumType sha256

}

function Uninstall-VS {
<#
.SYNOPSIS
Uninstalls Microsoft Visual C++ Build Tools

.DESCRIPTION
Uninstalls Microsoft Visual C++ Build Tools.

.PARAMETER PackageName
The name of the VisualCppBuildTools package.

.PARAMETER ApplicationName
The VisualStudio app name - i.e. 'Microsoft Visual C++ Build Tools'.

.PARAMETER UninstallerName
This name of the installer executable - i.e. 'vs_community.exe'.

.EXAMPLE
Uninstall-VS 'VisualCppBuildTools' 'Microsoft Visual C++ Build Tools' 'visualcppbuildtools_full.exe'

.OUTPUTS
None

.NOTES
This helper reduces the number of lines one would have to write to uninstall Visual Studio.
This method has no error handling built into it.

.LINK
Uninstall-ChocolateyPackage
#>
param(
  [string] $packageName,
  [string] $applicationName,
  [string] $uninstallerName
)
    Write-Debug "Running 'Uninstall-VS' for $packageName with url:`'$url`'";

    $installerType = 'exe'
    $silentArgs = '/Uninstall /force /Passive /NoRestart'

    $app = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like "$applicationName*"} | Sort-Object { $_.Name } | Select-Object -First 1
    if ($app -ne $null)
    {
        $uninstaller = Get-Childitem "$env:ProgramData\Package Cache\" -Recurse -Filter $uninstallerName | ? { $_.VersionInfo.ProductVersion.StartsWith($app.Version)}
        if ($uninstaller -ne $null)
        {
            Uninstall-ChocolateyPackage $packageName $installerType $silentArgs $uninstaller.FullName
        }
    }
}

Export-ModuleMember Install-VS, Uninstall-VS
