<#
.SYNOPSIS
	Read 1C7 log file
.DESCRIPTION
	This PowerShell script reads 1C7 log file and parses specified transaction.
.PARAMETER Path
    Log file path.
.PARAMETER ObjectFilters
    Object Id prefixes.
.PARAMETER TransactionTypeFilters
    Transaction types.
.PARAMETER StartDate
    Start date.
.PARAMETER Duration
    Duration.
#>

param(
    [Parameter(Mandatory)]
    [string]$Path,
    [Parameter(Mandatory)]
    [string[]]$ObjectFilters,
    [Parameter(Mandatory)]
    [string[]]$TransactionTypeFilters,
    [Parameter(Mandatory)]
    [DateTime]$StartDate,
    [Parameter(Mandatory)]
    [TimeSpan]$Duration
)

try {

    # Print arguments to user
    Write-Host ("Running with settings: " + (
        ConvertTo-Json -Compress @{ 
            Path = $Path; 
            ObjectFilter = $ObjectFilters; 
            TransactionTypeFilters = $TransactionTypeFilters;
            StartDate = $StartDate.ToString("yyyyMMdd;HH:mm:ss;");
            Duration = $Duration.ToString();
        }
    ))

    # Set up encoding
    $Encoding = [System.Text.Encoding]::GetEncoding(1251)

    $lineNumber = 1

    # Read file
    foreach ($line in [System.IO.File]::ReadLines($Path, $Encoding)) 
    {
        Write-Host "\rLines read: $lineNumber" -NoNewline

        $lineNumber++
    }

    Write-Host "Finished."
    exit 0
}
catch {
    Write-Host "Error in line $($_.InvocationInfo.ScriptLineNumber): $($Error[0])"
	exit 1
}
