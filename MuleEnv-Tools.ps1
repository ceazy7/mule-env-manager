# -------------------------------------------------------------------------
# Environment Cmdlets
# -------------------------------------------------------------------------

function global:Out-Env {
    Write-Host ""
    Write-Host -ForegroundColor DarkBlue "................................................................................"
    Write-Host -ForegroundColor DarkBlue "Mule Env"
    Write-Host -ForegroundColor DarkBlue "................................................................................"
    Write-Host ""
    Write-Host "current env:........", $currentEnvName
    Write-Host "currentVersion:.....", $currentVersion
    Write-Host -ForegroundColor DarkBlue "................................................................................"
    Write-Host "dev root:...........", $env:DEV_ROOT
    Write-Host "pwd env dir:........", $pwdEnv
    Write-Host "MavenHome:..........", $mavenHome
    Write-Host "repoloc:............", $repoloc
    Write-Host "settingsPath:.......", $settingsPath
    Write-Host -ForegroundColor DarkBlue "................................................................................"
    Write-Host "Anypoint Home.......", $studioDir
    Write-Host "JAVA_HOME...........", $env:JAVA_HOME
    Write-Host ""
}

# -------------------------------------------------------------------------
# Initialize functions
# -------------------------------------------------------------------------


# Initialize all variables that are used in the script
function global:Initialize-Script {
    $global:pwdEnv = (Get-Location).Path
    $global:mavenHome ="$pwdEnv\maven"
    $global:filePathToSettings = "$mavenHome\conf\settings.xml"
    $global:xpath = "//ns:localRepository"
    $global:repoloc = $pwdEnv.Replace("\", "/") + "/artifacts"
    $global:settingsPath = $filePathToSettings
    $global:inifile = "AnypointStudio.ini"
    $global:patchContent = @('-eclipse.keyring', '..\settings\secure-storage')
    #$global:patchContentWebView = @('-Dorg.eclipse.swt.browser.DefaultType=edge', '-Dorg.eclipse.swt.browser.EdgeDir=C:\ProgramData\Microsoft.WebView2.FixedVersionRuntime.126.0.2592.61.x64') #see https://help.salesforce.com/s/articleView?id=001119366&type=1
    $global:defaultNamespace = @{ns = "http://maven.apache.org/SETTINGS/1.1.0"}
    $global:StudioLocations = (Get-ChildItem -Include "AnypointStudio.exe" -Depth 1)
    $global:devBaseDir = (Get-Item "c:\dev")
    $global:currentEnvName = Split-Path -Path $pwdEnv -Leaf
    $global:studioDir = ""
    $global:wsDir = ""
    $global:asVersion = ""
    $global:previousMavenFound = $false
    $global:patchCacerts = $true

    $host.ui.RawUI.WindowTitle = "dev env - $currentEnvName"

    # save current time in millis for later use
    $global:currentMillis = Get-Date -UFormat %s 
    $global:currentMillis = $currentMillis.Replace(',', '')
    Write-Debug "currentMillis: $currentMillis"

    # set and if neccessary create the backup dir
    $backupDir = $pwdEnv + "\backup"
    if (-Not (Test-Path -Path $backupDir)) { New-Item -ItemType Directory -Path $backupDir }
    $global:backupDir = Get-Item ($backupDir)
    Write-Debug "backupDir: $backupDir"

    $global:7zipPath = "$env:ProgramFiles\7-Zip\7z.exe"
    if (-not (Test-Path -Path $7zipPath -PathType Leaf)) {
        throw "7 zip file '$7zipPath' not found"
    }
}

function global:Initialize-CurrentTimeMillis {
    $global:currentMillis = Get-Date -UFormat %s 
    $global:currentMillis = $currentMillis.Replace(',', '')
    Write-Debug "currentMillis: $currentMillis"
}

# Finds out and sets the current Anypoint Studio directory as script variable and env var
function global:Initialize-AsDir {
    $filter = "AS-7*"
    $asDirs = (Get-ChildItem . -Filter $filter)[-1]
    $Env:AS = $asDirs[0].BaseName
    $global:studioDir = $asDirs[0]
}

# Finds out and sets the current Anypoint Studio directory as script variable and env var
function global:Initialize-WsDir {
    $filter = "ws-7*"
    $wsDirs = (Get-ChildItem . -Filter $filter)[-1]
    $global:wsDir = $wsDirs[0]
}

# Finds out and sets the current JDK directory as script variable and env var
function global:Initialize-Jdk {
    $jdkDirs = (Get-ChildItem ($studioDir.FullName + "\plugins") -Filter "org.mule.tooling.jdk.win32.x86_64_*")
    $Env:JDK = $jdkDirs[0].BaseName
    $global:jdkDir = $jdkDirs[0]
}

# Finds out and sets the current JDK directory as script variable and env var
function global:Initialize-AsVersion {
    $currentAsVersion = $studioDir.BaseName.Substring(3)
    $global:asVersion = $currentAsVersion
}

# Initializes all required environment variables required for external processes, e.g. JAVA_HOME
function global:Initialize-EnvVars {
    $Env:ANYPOINT_HOME = $studioDir
    $Env:PACKAGE_HOME = $pwdEnv
    $Env:M2_HOME = $Env:PACKAGE_HOME + "\maven"
    $Env:MAVEN_HOME = $Env:PACKAGE_HOME + "\maven"
    $Env:JAVA_HOME = $jdkDir.FullName
    $Env:PATH = $Env:JAVA_HOME + "\bin;" + $Env:M2_HOME + "\bin;" + $Env:PATH
    $Env:M2_REPO = $Env:PACKAGE_HOME + "\m2repo"
    $Env:ENV_VERSION = if ($Env:ENV_VERSION) {$Env:ENV_VERSION} else {"4"}
    $Env:INIT_PS_SCRIPT = $Env:DEV_ROOT + "\project-tools.ps1"
}

# Calls all required Initialize functions to setup a environment
function global:Initialize-Env {
    Initialize-Script
    try {
        Initialize-AsDir
        Initialize-WsDir
        Initialize-Jdk
        Initialize-AsVersion
    } catch {
        "No previous installation found."
    }
    Initialize-EnvVars

    Out-Env
}

# -------------------------------------------------------------------------
# Update functions
# -------------------------------------------------------------------------

# defaults to change repo location element in the settings.xml file to the project-local m2repo dir
function global:Update-SettingsXml {
    param (
        [Parameter(Mandatory=$false, Position=0)]
        $file = $filePathToSettings,
        [Parameter(Mandatory=$false, Position=1)]
        $xpath = $xpath,
        [Parameter(Mandatory=$false, Position=2)]
        $value = $repoloc,
        [Parameter(Mandatory=$false, Position=3)]
        [hashtable]
        $ns = $defaultNamespace
    )
    Write-Host "getting file content from $file"
    [xml] $xml = Get-Content -Path $file
    $nsmanager = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
    foreach ($kvp in $ns.GetEnumerator()) {
        $nsmanager.AddNamespace($kvp.Key, $kvp.Value)
    }
    $element =  $xml.SelectSingleNode($xpath, $nsmanager)
    Write-Host "selected element:"$element.Name
    $element.InnerText = $value
    Write-Host "writing new value $value"
    $xml.Save($file)
    if (-Not (Test-Path -Path $repoloc)) { New-Item -ItemType Directory -Path $repoloc}
}

# patches the studio ini to use a custom secure storage
function global:Update-StudioSecureStorage {
    param (
        [Parameter(Mandatory=$false, Position=0)]
        $Path = (Get-ChildItem -Include $inifile -Depth 1)
    )
    if (-Not (Test-Path -Path ($pwdEnv + "\settings"))) { New-Item -ItemType Directory -Path ($pwdEnv + "\settings") }
    foreach ($itm in $Path) {
        Write-Host "processing $itm"
        $iniContent = (Get-Content $itm -Raw)
        if ($iniContent.Contains("-eclipse.keyring")) {
            Write-Host "already patched"
        } else {
            Write-Host "writing new secure storage path"
            Set-Content -Path $Path -Value ($patchContent + $iniContent)
        }
    }
}

# Patches the start script for Anypoint Studio to use the correct JDK version and Studio dir
function global:Update-StartScript {
    $filePath = $pwdEnv + "\templates\Set-Env.cmd"
    $fileContent = (Get-Content $filePath)
    $fileContent = $fileContent.Replace("##JDKDIR##", $jdkDir.FullName)
    $fileContent = $fileContent.Replace("##ASDIR##", $studioDir.FullName)
    Write-Debug "start script content: $fileContent"
    Set-Content -Path ($pwdEnv + "\Set-Env.cmd") -Value $fileContent
}

function global:Update-StudioDefaultWsLocation {
    $filter = "ws-7*"
    $wsDir = (Get-ChildItem . -Filter $filter)[-1]
    Write-Debug "wsDir: $wsDir"
    $filePath = $studioDir.FullName + "\configuration\.settings\org.eclipse.ui.ide.prefs"
    #$fileContent = (Get-Content $filePath)
    $fileContent = ""
    foreach ($line in Get-Content $filePath) {
        if ($line.StartsWith("RECENT_WORKSPACES=")) {
            #$newWsLocation = $line.Substring($line.LastIndexOf('=')+1)
            $newWsLocation = $wsDir.FullName.Replace('\', '\\').Replace(':', '\:')
            Write-Debug "newWsLocation: $newWsLocation"
            $line = "RECENT_WORKSPACES=" + $newWsLocation
        }
        #Write-Debug $line
        $fileContent += $line + "`r`n"
    }
    Write-Debug "File content:"
    Write-Debug $fileContent
    Write-Host "Default WS changed in $filePath"
    Set-Content -Path $filePath -Value $fileContent
}

# Patches both cacerts in Studio JDKs with additional root certificate
function global:Update-Cacerts {
    $javaDir = $jdkDir.FullName
    Start-Process -FilePath "$javaDir\bin\keytool.exe" -ArgumentList "-import -file $pwdEnv\templates\local-cert.cer -trustcacerts -alias ""mule-local"" -storepass changeit -cacerts -noprompt"
    Start-Sleep -Seconds 2
}

# Patch studio files with defaults 
function global:Update-Studio {
    # refresh the studioDir var to the new location
    Initialize-AsDir
    Write-Debug "studioDir: $studioDir"
    # initialize the vars pointint to the new JDK from the new Studio
    Initialize-Jdk
    
    $studioBackupSettingsDir = $studioBackupDir + "\configuration\.settings"
    $studioSettingsDir = $studioDir.FullName + "\configuration"
    Write-Debug "studioBackupSettingsDir: $studioBackupSettingsDir"
    Write-Debug "studioSettingsDir: $studioSettingsDir"
    $sourceStudioSettings = $pwdEnv + "\templates\.settings"
    # if previous studio settings files are found copy them to the new studio
    if (Test-Path -Path $studioBackupSettingsDir) {
        Write-Host "copying $studioBackupSettingsDir to $studioSettingsDir"
        $sourceStudioSettings = $studioBackupSettingsDir
    }
    # otherwise use the default settings files from the templates\.settings subdir
    Copy-Item -Path $sourceStudioSettings -Destination $studioSettingsDir -Recurse -Force

    # patch the studio INI file to use a distinct secure-storage location
    Update-StudioSecureStorage

    # patch the Studio start script to accomodate the new Studio and JDK locations
    Update-StartScript
    Copy-Item -Path ($pwdEnv + "\templates\Start-Studio.cmd") -Destination $pwdEnv -Force
    Copy-Item -Path ($pwdEnv + "\templates\Start-Console.cmd") -Destination $pwdEnv -Force

    # patch the cacerts in both JDKs in the studio to include the webgateway cert
    if ($patchCacerts) {
        Update-Cacerts
    }
    Update-StudioMemorySettings
}

# Patches the Studio INI file to increase max memory setting
function global:Update-StudioMemorySettings {
    Initialize-AsDir
    Write-Debug "studioDir: $studioDir"
    $filePath = $studioDir.FullName + "\AnypointStudio.ini"
    $fileContent = (Get-Content $filePath)
    $fileContent = $fileContent.Replace("-Xmx1024m", "-Xmx2048m")
    Write-Debug "start script content: $fileContent"
    Set-Content -Path ($studioDir.FullName + "\AnypointStudio.ini") -Value $fileContent
}

# Patch studio and workspace files with defaults 
function global:Update-Workspace {
    $filter = "ws-$asVersion"
    $wsDir = (Get-ChildItem . -Filter $filter)[-1]
    Copy-Item -Path ($pwdEnv + "\templates\.metadata") -Destination $wsDir -Recurse -Force

    # patch the settings file from studio with the recent workspace locations set to new default
    Update-StudioDefaultWsLocation
}

# Patch the settings file
function global:Update-Maven {    
    # maven backup dir for the currently installed maven
    $mavenHomeBackup = $mavenHome + ".$currentMillis"    
    # prepare to copy a settings.xml to the newly installed maven, either the template from templates subdir
    $settingsFileSource = $pwdEnv + "\templates\settings.xml"
    if ($previousMavenFound) {
        # or from the previous installation
        $settingsFileSource = $mavenHomeBackup + "\conf\settings.xml"
    }
    Copy-Item -Path $settingsFileSource -Destination ($pwdEnv + "\maven\conf")
    
    # finally move the old maven dir to the backup subdir
    if ($previousMavenFound) {
        Move-Item -Path $mavenHomeBackup -Destination $backupDir
    }

    # post-install, by patching the settings.xml to point the artifacts to the artifacts subdir
    Update-SettingsXml
}

# -------------------------------------------------------------------------
# Install functions
# -------------------------------------------------------------------------

# Extracts the Studio ZIP, installs all plugins and 
function global:Install-Studio {
    try {
        # try to set var studioDir to the latest Anypoint Studio dir in the present work directory
        Initialize-AsDir
        Write-Debug "studioDir: $studioDir"
        Initialize-AsVersion
        Write-Debug "asVersion: $asVersion"
    } catch {
    }

    # get the latest Anypoint Studio ZIP file from packages-subdir
    $asZip = (Get-ChildItem ($pwdEnv + "\packages") -Filter "AnypointStudio-*.zip")[-1]
    Write-Debug "asZip: $asZip"
    if (-not (Test-Path -Path $asZip.FullName -PathType Leaf)) {
        throw "Anypoint Studio ZIP not found in \\packages!"
    }

    # test the zip file and check for errors
    Start-7Zip t $asZip.FullName
    if ($LASTEXITCODE -gt 0) {
        throw "ZIP file is corrupt!"
    }

    # trim the ZIP file name to extract the Anypoint Studio (AS) version
    $asName = $asZip.BaseName.Replace("-win64", "")
    $global:asVersion = $asName.Substring($asName.LastIndexOf('-')+1)
    $global:asVersion = $asVersion.Substring(0, 4)
    Write-Debug "asVersion: $asVersion"

    Backup-Studio

    # now extract the Studio ZIP file
    Write-Host "expanding archive $asZip to $pwdEnv"
    # Expand-Archive -LiteralPath ($asZip.FullName) -DestinationPath $pwdEnv -Force
    Start-7Zip x -aoa -o"$pwdEnv" $asZip.FullName

    # and rename the default directory AnypointStudio to a shorter dir with version included
    if (Test-Path -Path "AnypointStudio") {
        Start-Sleep -Seconds 3
        Rename-Item -Path "AnypointStudio" -NewName ("AS-" + $asVersion)
    }

    Install-StudioPlugins
}

# Install studio plugins
function global:Install-StudioPlugins {
    # refresh the studioDir var to the new location
    Initialize-AsDir
    Write-Debug "studioDir: $studioDir"
    # initialize the vars pointint to the new JDK from the new Studio
    Initialize-Jdk
    
    # extract all plugin ZIPs in the packages\plugins subdir into the Studio dir
    $pluginsZip = (Get-ChildItem ($pwdEnv + "\packages\plugins") -Filter "*.zip")
    foreach ($pluginZip in $pluginsZip) {
        Write-Debug "expanding archive $pluginzip to $studioDir"
        #Expand-Archive -LiteralPath ($pluginZip.FullName) -DestinationPath $studioDir -Force
        Start-7Zip x -aoa -o"$studioDir" $pluginZip.FullName
    }
}

function global:Backup-Studio {
    param (
        [Parameter(Mandatory=$false, Position=0)]
        $currentStudioDir = $studioDir
    )

    # and set the Studio backup dir name by using currently installed Studio dir and append time in millis
    $studioBackupDir = $currentStudioDir.FullName + ".$currentMillis"
    $asPreviousVersion = ""
    # if a previous installation of Studio is found
    if ($currentStudioDir -And (Test-Path -Path $currentStudioDir)) {
        # rename the dir to the studio backup dir name
        Rename-Item -Path $currentStudioDir -NewName $studioBackupDir
        $studioBackupDir = Get-Item ($studioBackupDir)
        Write-Debug "studioBackupDir: $studioBackupDir"
        # move the renamed folder to the backup subdir
        Move-Item -Path $studioBackupDir -Destination $backupDir
        $studioBackupDir = $backupDestination
        Write-Debug "studioBackupDir: $studioBackupDir"
        # extract the previous version from the directory name
        $asPreviousVersion = $currentStudioDir.BaseName.Substring($currentStudioDir.BaseName.LastIndexOf('-')+1)
        $asPreviousVersion = $asPreviousVersion.Substring(0, 4)
        Write-Debug "asPreviousVersion: $asPreviousVersion"
    }

}

# Setup workspace 
function global:Install-Workspace {
    try {
        Initialize-WsDir
    } catch {
    }
    $filter = "ws-$asVersion"
    #$wsNewDir = (Get-ChildItem . -Filter $filter)
    $wsNewDir = $filter
    if ($wsDir) {
        if (-Not (Test-Path -Path $wsNewDir)) { New-Item -ItemType Directory -Path $wsNewDir}
        Write-Debug "filter: $filter"
        Write-Debug "wsNewDir: $wsNewDir"
        # if workspace is found rename it by appending the timestamp millis
        $wsBackupDir = "$wsDir.$currentMillis"
        Write-Debug "wsBackupDir: $wsBackupDir"
        Write-Debug "backupDir: $backupDir"
        Rename-Item -Path $wsDir -NewName $wsBackupDir
        # then copy the content to the new workspace matching the current studio version
        Copy-Item -Path ($wsBackupDir + "\*") -Destination $wsNewDir -Recurse -Force
        # and move the old workspace to the backup subdir
        Move-Item -Path $wsBackupDir -Destination $backupDir
    } else {
        New-Item -ItemType Directory -Name $filter
    }
}


# Extract the maven zip and create a backup of an existing installation
function global:Install-Maven {
    # maven backup dir for the currently installed maven
    $mavenHomeBackup = $mavenHome + ".$currentMillis"
    if (Test-Path -Path $mavenHome) {
        # if maven is already present, rename the current dir
        Write-Debug "mavenHomeBackup: $mavenHomeBackup"
        Rename-Item -Path $mavenHome -NewName $mavenHomeBackup
        $global:previousMavenFound = $true
    }
    # get the latest maven zip from packages subdir
    $mavenZip = (Get-ChildItem ($pwdEnv + "\packages") -Filter "apache-maven-*.zip")[-1]
    Write-Debug "mavenZip: $mavenZip"
    
    # test the zip file and check for errors
    Start-7Zip t $mavenZip.FullName
    if ($LASTEXITCODE -gt 0) {
        throw "ZIP file is corrupt!"
    }

    # and extract the maven zip from packages subdir
    Write-Host "expanding archive $mavenZip to $pwdEnv"
    # Expand-Archive -LiteralPath ($mavenZip.FullName) -DestinationPath $pwdEnv -Force
    Start-7Zip x -aoa -o"$pwdEnv" $mavenZip.FullName

    $mavenPackageName = $mavenZip.BaseName.Substring(0, $mavenZip.BaseName.LastIndexOf('-'))
    Write-Debug "mavenPackageName: $mavenPackageName"
    # then rename the default apache maven folder to folder without version in name
    Start-Sleep -Seconds 3
    Rename-Item -Path $mavenPackageName -NewName "maven"
}

function global:Install-MuleEnv {
    #$DebugPreference = "Continue"
    #Initialize-Env
    try {
        Install-Studio
        Update-Studio
        Install-Workspace
        Update-Workspace
        Install-Maven
        Update-Maven
    } catch {
        #Write-Host $_
        $formatstring = "{0}:{1}`n{2}`n" +
        "    + CategoryInfo          : {3}`n" +
        "    + FullyQualifiedErrorId : {4}`n"
        $fields = $_.InvocationInfo.MyCommand.Name,
        $_.ErrorDetails.Message,
        $_.InvocationInfo.PositionMessage,
        $_.CategoryInfo.ToString(),
        $_.FullyQualifiedErrorId
        Write-Host -Foreground Red -Background Black ($formatstring -f $fields)

        throw "Error! Installation aborted!"
    }
    Initialize-Env
    Write-Host "Done."
}

function global:Update-MuleEnv {
    #$DebugPreference = "Continue"
    #Initialize-Env
    try {
        Update-Studio
        Update-Workspace
        Update-Maven
    } catch {
        #Write-Host $_
        $formatstring = "{0}:{1}`n{2}`n" +
        "    + CategoryInfo          : {3}`n" +
        "    + FullyQualifiedErrorId : {4}`n"
        $fields = $_.InvocationInfo.MyCommand.Name,
        $_.ErrorDetails.Message,
        $_.InvocationInfo.PositionMessage,
        $_.CategoryInfo.ToString(),
        $_.FullyQualifiedErrorId
        Write-Host -Foreground Red -Background Black ($formatstring -f $fields)

        throw "Error! Installation aborted!"
    }
    Initialize-Env
    Write-Host "Done."
}

# -------------------------------------------------------------------------
# Clear functions
# -------------------------------------------------------------------------

function global:Clear-MuleEnv {
    param (
        [switch]$HardReset
    )
    $shell = New-Object -ComObject 'Shell.Application'
    $itemsToDelete = Get-ChildItem -Path $pwdEnv -Exclude templates,packages,Install-MuleEnv*.cmd,MuleEnv-Tools.ps1,Start-MuleShell*.cmd,README.md,projects,backup
    foreach ($itm in $itemsToDelete) {
        Write-Debug "deleting $itm"
        if ($HardReset) {
            Remove-Item $itm -Force -Recurse
        } else {
            $shell.NameSpace(0).ParseName($itm.FullName).InvokeVerb('delete')
        }
    }
    Write-Host "Done."
}

# -------------------------------------------------------------------------
# Build functions
# -------------------------------------------------------------------------

function global:Build-MuleEnvSetupPackage {
    $Target = $pwdEnv + "\muleenv-setup.zip"
    Start-SevenZip a -tzip -mx=0 $Target ($pwdEnv + "\packages") ($pwdEnv + "\templates") ($pwdEnv + "\Install-MuleEnv.cmd") ($pwdEnv + "\Install-MuleEnvV7.cmd") ($pwdEnv + "\MuleEnv-Tools.ps1") ($pwdEnv + "\Start-MuleShell.cmd") ($pwdEnv + "\Start-MuleShellV7.cmd") ($pwdEnv + "\README.md")
    Write-Host "Done."
}

function global:Build-MuleEnvPackage {
    # Only needed if using Windows PowerShell (.NET Framework):
    # Add-Type -AssemblyName System.IO.Compression.FileSystem
    # [IO.Compression.ZipFile]::CreateFromDirectory($sourceDirectory, $destinationArchive)

    # $compress = @{
    #     Path= $studioDir.FullName, $wsDir.FullName, ($pwdEnv + "\maven"), ($pwdEnv + "\artifacts"), ($pwdEnv + "\packages"), ($pwdEnv + "\settings"), ($pwdEnv + "\templates"), ($pwdEnv + "\Set-Env.cmd"), ($pwdEnv + "\Install-MuleEnv.cmd"), ($pwdEnv + "\Install-MuleEnvV7.cmd"), ($pwdEnv + "\MuleEnv-Tools.ps1"), ($pwdEnv + "\Start-Console.cmd"), ($pwdEnv + "\Start-Studio.cmd")
    #     CompressionLevel = "Fastest"
    #     DestinationPath = $pwdEnv + "\muleenv.zip"
    # }
    # Compress-Archive @compress
    $Target = $pwdEnv + "\muleenv.zip"
    Start-SevenZip a -tzip -mx=0 $Target $studioDir.FullName $wsDir.FullName ($pwdEnv + "\maven") ($pwdEnv + "\artifacts") ($pwdEnv + "\packages") ($pwdEnv + "\settings") ($pwdEnv + "\templates") ($pwdEnv + "\Set-Env.cmd") ($pwdEnv + "\Install-MuleEnv.cmd") ($pwdEnv + "\Install-MuleEnvV7.cmd") ($pwdEnv + "\MuleEnv-Tools.ps1") ($pwdEnv + "\Start-Console.cmd") ($pwdEnv + "\Start-Studio.cmd") ($pwdEnv + "\Start-MuleShell.cmd") ($pwdEnv + "\Start-MuleShellV7.cmd") ($pwdEnv + "\README.md")
    Write-Host "Done."
}


# -------------------------------------------------------------------------
# Main
# -------------------------------------------------------------------------

$DebugPreference = "Continue"
Initialize-Env
Set-Alias -Option AllScope -Scope Global Start-SevenZip $7zipPath
Set-Alias -Option AllScope -Scope Global Start-7Zip $7zipPath
