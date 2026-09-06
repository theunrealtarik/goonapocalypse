[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$Install,
    [switch]$Package,
    [switch]$Run,
    [switch]$Upload,
    [switch]$All,

    [switch]$NoAutoInstall,
    [switch]$NoCleanupAfterUpload,

    [string]$ModName = "Goonapocalypse",

    [string]$SteamAppsCommon = (Join-Path ${env:ProgramFiles(x86)} "Steam\steamapps\common"),

    [string]$AppId = "108600",
    [string]$WorkshopId,
    [switch]$NewWorkshopItem,
    [string]$Title,
    [string]$PreviewPath,
    [string]$DescriptionPath,
    [string]$PatchNotePath,
    [string]$Tags,
    [int]$Visibility = -1,
    [string]$Language,
    [string]$SteamUploaderPath = "SteamUploader"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$ScriptBoundParams = $PSBoundParameters

$RepoRoot      = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$ZomboidRoot   = Join-Path $env:USERPROFILE "Zomboid"
$InstallDest   = Join-Path $ZomboidRoot "Mods\$ModName"
$WorkshopRoot  = Join-Path $ZomboidRoot "Workshop\$ModName"
$PackageDest   = Join-Path $WorkshopRoot "Contents\mods\$ModName"
$UploadContent = Join-Path $WorkshopRoot "Contents"
$GameLauncher  = Join-Path $SteamAppsCommon "ProjectZomboid\ProjectZomboid64.bat"

$TopLevelIgnore = @(
    ".git"
    ".vscode"
    ".zed"
    "lib"
    "dist"
    "assets"
    "scripts"
    "workshop"
)

function Test-GitAvailable
{
    if (-not (Get-Command git -ErrorAction SilentlyContinue))
    {
        throw "git is required for -Package so it can respect .gitignore."
    }
}

function Test-GitIgnored
{
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$RelativePath
    )

    git -C $RepoRoot check-ignore -q -- $RelativePath
    return ($LASTEXITCODE -eq 0)
}

function Get-PackagedRelativePaths
{
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string[]]$TopLevelIgnore
    )

    $Listed = @(
        git -C $RepoRoot ls-files --cached --exclude-standard
        git -C $RepoRoot ls-files --others --exclude-standard
    ) | ForEach-Object { $_ -replace "/", "\" } | Where-Object { $_ } | Select-Object -Unique

    $IgnoreSet = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($Name in $TopLevelIgnore)
    {
        [void]$IgnoreSet.Add($Name)
    }

    foreach ($Rel in $Listed)
    {
        $Top = ($Rel -split "\\")[0]
        if ($IgnoreSet.Contains($Top))
        {
            continue
        }
        if (Test-GitIgnored -RepoRoot $RepoRoot -RelativePath $Rel)
        {
            continue
        }
        $Rel
    }
}

function Copy-RelativeFiles
{
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$Destination,
        [Parameter(Mandatory)][string[]]$RelativePaths
    )

    New-Item -ItemType Directory -Path $Destination -Force | Out-Null

    foreach ($Rel in $RelativePaths)
    {
        $Source = Join-Path $RepoRoot $Rel
        if (-not (Test-Path -LiteralPath $Source))
        {
            continue
        }

        $Target = Join-Path $Destination $Rel
        $TargetDir = Split-Path $Target -Parent
        if (-not (Test-Path -LiteralPath $TargetDir))
        {
            New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
        }

        Copy-Item -LiteralPath $Source -Destination $Target -Force
    }
}

function Get-UploadConfig
{
    param(
        [Parameter(Mandatory)][string]$ConfigPath
    )

    if (-not (Test-Path -LiteralPath $ConfigPath))
    {
        return $null
    }

    try
    {
        return Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
    } catch
    {
        throw "Failed to parse '$ConfigPath' as JSON: $($_.Exception.Message)"
    }
}

function Get-ConfigValue
{
    param(
        $Config,
        [Parameter(Mandatory)][string]$Name
    )

    if ($null -eq $Config)
    {
        return $null
    }
    if ($Config.PSObject.Properties.Name -contains $Name)
    {
        return $Config.$Name
    }
    return $null
}

function Resolve-ConfigPath
{
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        $Path
    )

    if (-not $Path)
    {
        return $null
    }
    if ([System.IO.Path]::IsPathRooted($Path))
    {
        return $Path
    }
    return (Join-Path $RepoRoot $Path)
}

function Resolve-UploadSetting
{
    param(
        [Parameter(Mandatory)][string]$Name,
        $CliValue,
        $ConfigValue
    )

    if ($script:ScriptBoundParams.ContainsKey($Name))
    {
        return $CliValue
    }
    if ($null -ne $ConfigValue -and "$ConfigValue" -ne "")
    {
        return $ConfigValue
    }
    return $CliValue
}

function Invoke-Install
{
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$Destination,
        [Parameter(Mandatory)][string[]]$TopLevelIgnore
    )

    if (-not $PSCmdlet.ShouldProcess($Destination, "Deploy mod (fast copy)"))
    {
        return
    }

    Remove-Item -LiteralPath $Destination -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null

    Get-ChildItem -LiteralPath $RepoRoot -Force |
        Where-Object { $_.Name -notin $TopLevelIgnore } |
        ForEach-Object {
            $Target = Join-Path $Destination $_.Name
            Copy-Item -LiteralPath $_.FullName -Destination $Target -Recurse -Force
        }

    Write-Host "Installed $ModName -> $Destination"
}

function Invoke-Package
{
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$WorkshopRoot,
        [Parameter(Mandatory)][string]$PackageDest,
        [Parameter(Mandatory)][string[]]$TopLevelIgnore
    )

    Test-GitAvailable

    if (-not $PSCmdlet.ShouldProcess($PackageDest, "Package mod for Workshop (git-aware copy)"))
    {
        return
    }

    if (Test-Path -LiteralPath $PackageDest)
    {
        Remove-Item -LiteralPath $PackageDest -Recurse -Force
    }

    $ModFiles = @(Get-PackagedRelativePaths -RepoRoot $RepoRoot -TopLevelIgnore $TopLevelIgnore)
    Copy-RelativeFiles -RepoRoot $RepoRoot -Destination $PackageDest -RelativePaths $ModFiles

    New-Item -ItemType Directory -Path $WorkshopRoot -Force | Out-Null

    $WorkshopSource = Join-Path $RepoRoot "workshop"
    if (Test-Path -LiteralPath $WorkshopSource)
    {
        Get-ChildItem -LiteralPath $WorkshopSource -Force | ForEach-Object {
            $Rel = Join-Path "workshop" $_.Name
            if (Test-GitIgnored -RepoRoot $RepoRoot -RelativePath $Rel)
            {
                return
            }

            $Target = Join-Path $WorkshopRoot $_.Name
            if ($_.PSIsContainer)
            {
                Copy-Item -LiteralPath $_.FullName -Destination $Target -Recurse -Force
            } else
            {
                Copy-Item -LiteralPath $_.FullName -Destination $Target -Force
            }
        }
    }

    Write-Host "Packaged $ModName workshop:"
    Write-Host "`t$WorkshopRoot"
    Write-Host "Mod contents:"
    Write-Host "`t$PackageDest"
}

function Invoke-Run
{
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$GameLauncher
    )

    if (-not (Test-Path -LiteralPath $GameLauncher))
    {
        throw "Could not find Project Zomboid launcher at:`n`t$GameLauncher`nPass -SteamAppsCommon to override the Steam location."
    }

    if (-not $PSCmdlet.ShouldProcess($GameLauncher, "Launch Project Zomboid"))
    {
        return
    }

    Write-Host "Launching Project Zomboid..."
    & $GameLauncher
}

function Invoke-Upload
{
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$ModName,
        [Parameter(Mandatory)][string]$ContentPath,
        [Parameter(Mandatory)][string]$PackageRoot,
        [Parameter(Mandatory)][string]$SteamUploaderPath,
        [Parameter(Mandatory)][string]$AppId,
        [string]$WorkshopId,
        [switch]$NewWorkshopItem,
        [string]$Title,
        [string]$PreviewPath,
        [string]$DescriptionPath,
        [string]$PatchNotePath,
        [string]$Tags,
        [int]$Visibility = -1,
        [string]$Language,
        [switch]$CleanupAfterUpload
    )

    $Uploader = Get-Command $SteamUploaderPath -ErrorAction SilentlyContinue
    if (-not $Uploader)
    {
        throw "Could not find SteamUploader at '$SteamUploaderPath'.`nGet it from https://github.com/SimKDT/Steam-Uploader and pass -SteamUploaderPath <path>, or add it to PATH."
    }

    if (-not $NewWorkshopItem -and -not $WorkshopId)
    {
        throw "-Upload requires -WorkshopId <id>, or pass -NewWorkshopItem to publish a brand-new Workshop item."
    }

    if (-not (Test-Path -LiteralPath $ContentPath))
    {
        throw "Nothing to upload: '$ContentPath' does not exist. -Package should have created it."
    }

    $UploaderArgs = @("--appID", $AppId, "--content", $ContentPath)

    if ($NewWorkshopItem)
    {
        $UploaderArgs += "--new"
    } else
    {
        $UploaderArgs += @("--workshopID", $WorkshopId)
    }

    $EffectiveTitle = if ($Title)
    { $Title
    } elseif ($NewWorkshopItem)
    { $ModName
    } else
    { $null
    }
    if ($EffectiveTitle)
    {
        $UploaderArgs += @("--title", $EffectiveTitle)
    }

    if ($PreviewPath)
    { $UploaderArgs += @("--preview", $PreviewPath)
    }
    if ($DescriptionPath)
    { $UploaderArgs += @("--description", $DescriptionPath)
    }
    if ($PatchNotePath)
    { $UploaderArgs += @("--patchNote", $PatchNotePath)
    }
    if ($Tags)
    { $UploaderArgs += @("--tags", $Tags)
    }
    if ($Visibility -ge 0)
    { $UploaderArgs += @("--visibility", $Visibility)
    }
    if ($Language)
    { $UploaderArgs += @("--language", $Language)
    }

    if (-not $PSCmdlet.ShouldProcess($ContentPath, "Upload to Steam Workshop (appID $AppId)"))
    {
        return
    }

    Write-Host "Uploading $ModName to Steam Workshop (appID $AppId)..."
    & $Uploader.Source @UploaderArgs

    if ($LASTEXITCODE -ne 0)
    {
        throw "SteamUploader exited with code $LASTEXITCODE."
    }

    Write-Host "Upload complete."

    if ($CleanupAfterUpload)
    {
        if ($PSCmdlet.ShouldProcess($PackageRoot, "Delete local package folder"))
        {
            Remove-Item -LiteralPath $PackageRoot -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "Cleaned up local package folder: $PackageRoot"
        }
    }
}

if ($All)
{
    $Install = $true
    $Package = $true
}

if ($Upload)
{
    $Package = $true
}

if ($Run -and -not $Install -and -not $Package)
{
    $Install = $true
} elseif ($Run -and -not $Install -and -not $NoAutoInstall)
{
    $Install = $true
}

if (-not ($Install -or $Package -or $Run -or $Upload))
{
    Write-Host "Usage: .\manage.ps1 [-Install] [-Package] [-Run] [-Upload] [-All] [-ModName <name>] [-SteamAppsCommon <path>]"
    Write-Host ""
    Write-Host "  -Install   Fast-copy the repo into the local Zomboid Mods folder."
    Write-Host "  -Package   Git-aware build into the Zomboid Workshop Content folder."
    Write-Host "  -Run       Launch Project Zomboid (implies -Install)."
    Write-Host "  -Upload    Push the packaged build to the Steam Workshop (implies -Package)."
    Write-Host "             Requires -WorkshopId <id>, or -NewWorkshopItem to publish new."
    Write-Host "             Optional: -PreviewPath -DescriptionPath -PatchNotePath -Tags"
    Write-Host "             -Title -Visibility 0-3 -Language -SteamUploaderPath -AppId"
    Write-Host "             Defaults for all of these can live in workshop\upload.json;"
    Write-Host "             any flag passed on the command line overrides the file."
    Write-Host "             Deletes the local package folder after a successful upload;"
    Write-Host "             pass -NoCleanupAfterUpload to keep it around."
    Write-Host "  -All       Shorthand for -Install and -Package."
    return
}

if ($Upload)
{
    $UploadConfigPath = Join-Path $RepoRoot "workshop\upload.json"
    $UploadConfig = Get-UploadConfig -ConfigPath $UploadConfigPath

    $ConfigTags = Get-ConfigValue -Config $UploadConfig -Name "tags"
    if ($ConfigTags -is [array])
    {
        $ConfigTags = $ConfigTags -join ","
    }

    $RAppId           = Resolve-UploadSetting -Name "AppId"           -CliValue $AppId           -ConfigValue (Get-ConfigValue -Config $UploadConfig -Name "appId")
    $RWorkshopId      = Resolve-UploadSetting -Name "WorkshopId"      -CliValue $WorkshopId       -ConfigValue (Get-ConfigValue -Config $UploadConfig -Name "workshopId")
    $RTitle           = Resolve-UploadSetting -Name "Title"           -CliValue $Title            -ConfigValue (Get-ConfigValue -Config $UploadConfig -Name "title")
    $RTags            = Resolve-UploadSetting -Name "Tags"            -CliValue $Tags             -ConfigValue $ConfigTags
    $RVisibility      = Resolve-UploadSetting -Name "Visibility"      -CliValue $Visibility       -ConfigValue (Get-ConfigValue -Config $UploadConfig -Name "visibility")
    $RLanguage        = Resolve-UploadSetting -Name "Language"        -CliValue $Language         -ConfigValue (Get-ConfigValue -Config $UploadConfig -Name "language")
    $RPreviewPath     = Resolve-UploadSetting -Name "PreviewPath"     -CliValue $PreviewPath      -ConfigValue (Resolve-ConfigPath -RepoRoot $RepoRoot -Path (Get-ConfigValue -Config $UploadConfig -Name "previewPath"))
    $RDescriptionPath = Resolve-UploadSetting -Name "DescriptionPath" -CliValue $DescriptionPath  -ConfigValue (Resolve-ConfigPath -RepoRoot $RepoRoot -Path (Get-ConfigValue -Config $UploadConfig -Name "descriptionPath"))
    $RPatchNotePath   = Resolve-UploadSetting -Name "PatchNotePath"   -CliValue $PatchNotePath    -ConfigValue (Resolve-ConfigPath -RepoRoot $RepoRoot -Path (Get-ConfigValue -Config $UploadConfig -Name "patchNotePath"))

    if (-not $NewWorkshopItem -and -not $RWorkshopId)
    {
        throw "-Upload requires -WorkshopId <id> (via flag or workshop\upload.json), or pass -NewWorkshopItem to publish a brand-new Workshop item."
    }
}

if ($Install)
{
    Invoke-Install -RepoRoot $RepoRoot -Destination $InstallDest -TopLevelIgnore $TopLevelIgnore
}

if ($Package)
{
    Invoke-Package -RepoRoot $RepoRoot -WorkshopRoot $WorkshopRoot -PackageDest $PackageDest -TopLevelIgnore $TopLevelIgnore
}

if ($Upload)
{
    Invoke-Upload -ModName $ModName -ContentPath $UploadContent -PackageRoot $WorkshopRoot -SteamUploaderPath $SteamUploaderPath `
        -AppId $RAppId -WorkshopId $RWorkshopId -NewWorkshopItem:$NewWorkshopItem -Title $RTitle `
        -PreviewPath $RPreviewPath -DescriptionPath $RDescriptionPath -PatchNotePath $RPatchNotePath `
        -Tags $RTags -Visibility $RVisibility -Language $RLanguage -CleanupAfterUpload:(-not $NoCleanupAfterUpload)
}

if ($Run)
{
    Invoke-Run -GameLauncher $GameLauncher
}
