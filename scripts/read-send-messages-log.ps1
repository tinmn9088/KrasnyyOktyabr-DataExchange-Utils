<#
.SYNOPSIS
	Read send messages from service log
.DESCRIPTION
	This PowerShell script reads service log and looks for messages sent to Kafka.
.PARAMETER Path
    Log file path.
#>

param(
    [Parameter(Mandatory)]
    [string]$Path
)

# ⚙️ Message regex
$MESSAGE_REGEX = New-Object 'Regex' '(?<timestamp>.*?)\|(?<level>.*?)\|(?<source>.*?)\|(?<text>.*)'

# ⚙️ Message text regex
$MESSAGE_TEXT_REGEX = New-Object 'Regex' '\"\u041D\u043E\u043C\u0435\u0440\u0414\u043E\u043A\":\"(?<docNumber>.*?)\"'

# ⚙️ Function to process message
function Get-SendMessageInfo {

    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    $Match = $MESSAGE_REGEX.Match($Message)

    if ($Match.Success) {
        $Groups = $Match.Groups
        $Source = $Groups['source'].Value

        if ($Source.EndsWith('ProducerService')) {
            $Text = $Groups['text'].Value

            if ($Text.StartsWith('Message sent to')) {
                $TextMatch = $MESSAGE_TEXT_REGEX.Match($Text)
                
                if ($TextMatch.Success) {
                    $TextGroups = $TextMatch.Groups
                    return $TextGroups['docNumber'].Value
                }
                else {
                    return "[WARN] DocNumber missing"
                }
            }
        }
    }

    return $null
}

try {

    # ⌛ 1/3 Prepare settings

    # Determine full path of the log file
    $Path = [System.IO.Path]::GetFullPath($Path)

    # Print settings to user
    Write-Host ('Running with settings: ' + (
        ConvertTo-Json @{ 
            Path = $Path; 
        }
    ))

    # ⌛ 2/3 Read file
    $Lines = [System.IO.File]::ReadLines($Path)
    $SendMessagesFound = 0

    foreach ($Line in $Lines) {
        $Result = (Get-SendMessageInfo $Line)

        if (-not ($null -eq $Result)) {
            $SendMessagesFound++

            # 📢 Write to ouput
            Write-Output $Result
        }
    }

    # ⌛ 3/3 Print stats
    Write-Host "Send messages found: $SendMessagesFound"
    exit 0
}
catch {
    # ⚠️ Print error description
    Write-Host "Error in line $($_.InvocationInfo.ScriptLineNumber): $($Error[0])"
	exit 1
}