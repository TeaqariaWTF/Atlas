param (
    [array]$Disable,
    [array]$Enable
)

$removableDrivePath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"
$removableDriveValue = "NoDrivesInSendToMenu"
# First value in an array is the disable, second is enable
$items = @{
    "Removable Drives" = @(
        { New-ItemProperty -Path $removableDrivePath -Name $removableDriveValue -Value 1 -PropertyType DWORD -Force },
        { Remove-ItemProperty -Path $removableDrivePath -Name $removableDriveValue -Force -EA 0 }
    )
}
$sendTo = Get-ChildItem ([Environment]::GetFolderPath('SendTo')) -Force
$shell = New-Object -Com WScript.Shell

# Get Bluetooth path
foreach ($lnk in (($sendTo | Where-Object { $_.Extension -eq ".lnk" }).FullName)) {
    if ($shell.CreateShortcut($lnk).TargetPath -like '*fsquirt.exe*') {
        $items["Bluetooth"] = $lnk
        $blueFound = $true
    } elseif ($shell.CreateShortcut($lnk).TargetPath -like '*wfs.exe /SendTo*') {
        $items["Fax recipient"] = $lnk
        $faxFound = $true
    }

    if ($faxFound -and $blueFound) {
        break
    }
}

# Items with specific extensions
foreach ($ext in @{
    "Compressed (zipped) folder" = "ZFSendToTarget"
    "Desktop (create shortcut)" = "DeskLink"
    "Mail recipient" = "MAPIMail"
    "Documents" = "mydocs"
}.GetEnumerator()) {
    $path = $sendTo | Where-Object { $_.Extension -eq ".$($ext.Value)" } | Select-Object -First 1
    if ($path) { $items[$ext.Key] = $path.FullName }
}

# Enable/disable functions
function EnableSendTo($value) {
    if ($value -is [string]) {
        $item = Get-Item -LiteralPath $value -Force
        $item.Attributes = $item.Attributes -band -bnot [System.IO.FileAttributes]::Hidden
    } elseif ($value -is [array]) {
        & $value[1] | Out-Null
    }
}
function DisableSendTo($value) {
    if ($value -is [string]) {
        $item = Get-Item -LiteralPath $value -Force
        $item.Attributes = $item.Attributes -bor [System.IO.FileAttributes]::Hidden
    } elseif ($value -is [array]) {
        & $value[0] | Out-Null
    }
}

# Args
if ($Enable) {
    foreach ($item in $items.GetEnumerator()) {
        foreach ($itemToEnable in $Enable) {
            if ($item.Key -like "$itemToEnable") {
                EnableSendTo $item.Value
            }
        }
    }
    exit
} elseif ($Disable) {
    foreach ($item in $items.GetEnumerator()) {
        foreach ($itemToDisable in $Disable) {
            if ($item.Key -like "$itemToDisable") {
                DisableSendTo $item.Value
            }
        }
    }
    exit
}

# Prompt user
$choices = (multichoice.exe "Send To Debloat" `
    "Tick the default 'Send To' context menu items that you want to enable here (un-checked items are disabled)" `
    "$($items.Keys -join ';')") -split ';'

# Loop through choices
foreach ($item in $items.GetEnumerator()) {
    $value = $item.Value
    # If it's in the choices, enable
    if ($item.Key -in $choices) {
        EnableSendTo $value
        continue
    }
    # If it's in the choices, disable
    if ($item.Key -notin $choices) {
        DisableSendTo $value
        continue
    }
}

# Restart Explorer prompt
Add-Type -AssemblyName System.Windows.Forms
if (([System.Windows.Forms.MessageBox]::Show(
    "Would you like to restart Windows Explorer now? This will finalise the changes.",
    "Atlas - Send To Debloat",
    [System.Windows.Forms.MessageBoxButtons]::YesNo,
    [System.Windows.Forms.MessageBoxIcon]::Information
)) -eq [System.Windows.Forms.DialogResult]::Yes) {
    Stop-Process -Name explorer -Force
}