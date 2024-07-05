<#
.SYNOPSIS
	Read 1C7 log file
.DESCRIPTION
	This PowerShell script reads 1C7 log file and looks for transactions.
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
    [string]$Path = '1cv7.mlg',
    [Parameter(Mandatory)]
    [string[]]$ObjectFilters,
    [Parameter(Mandatory)]
    [string[]]$TransactionTypeFilters,
    [DateTime]$StartDate = [DateTime]::Today,
    [TimeSpan]$Duration = (New-TimeSpan -Days 1)
)

# ⚙️ Transaction regex
$TRANSACTION_REGEX = New-Object 'Regex' '(?<date>.*?);(?<time>.*?);(?<user>.*?);(.*?);(.*?);(?<type>.*?);(.*?);(.*?);(?<id>.*?);(?<message>.*)'

# ⚙️ Message regex
$MESSAGE_REGEX = New-Object 'Regex' '.*\s(?<docNumber>[^\s]+)\s(?<date>\d{2}\.\d{2}\.\d{4})\s(?<time>\d{2}\:\d{2}\:\d{2})'

# ⚙️ Function to process transactions
function Get-TransactionInfo {

    param(
        [Parameter(Mandatory)]
        [string]$Transaction, 
        [Parameter(Mandatory)]
        [string[]]$ObjectFilters, 
        [Parameter(Mandatory)]
        [string[]]$TransactionTypeFilters
    )

    $Match = $TRANSACTION_REGEX.Match($Transaction)

    if ($Match.Success) {
        $Groups = $Match.Groups

        $ObjectId = $Groups['id'].Value
        $TransactionType = $Groups['type'].Value

        :loop foreach ($ObjectFilter in $ObjectFilters) {
            if ($ObjectId.StartsWith($ObjectFilter)) {
                foreach ($TransactionTypeFilter in $TransactionTypeFilters) {
                    if ($TransactionType -eq $TransactionTypeFilter) {
                        $Message = $Groups['message'].Value
                        $MessageMatch = $MESSAGE_REGEX.Match($Message)
                
                        if ($MessageMatch.Success) {
                            $MessageGroups = $MessageMatch.Groups
                            return $MessageGroups['docNumber'].Value
                        }
                        else {
                            return "[WARN] DocNumber missing"
                        }
                    }
                }
            }
        }
    }

    return $null
}

try {

    # ⌛ 1/5 Prepare settings

    # Determine full path of the log file
    $Path = [System.IO.Path]::GetFullPath($Path)

    # Determine prefixes of the searched transaction
    $TRANSACTION_DATE_FORMAT = 'yyyyMMdd;HH:mm:ss;'
    $StartTransactionPrefix = $StartDate.ToString($TRANSACTION_DATE_FORMAT)
    $EndTransactionPrefix = ($StartDate + $Duration).ToString($TRANSACTION_DATE_FORMAT)

    # Print settings to user
    Write-Host ('Running with settings: ' + (
        ConvertTo-Json @{ 
            Path = $Path; 
            ObjectFilters = $ObjectFilters; 
            TransactionTypeFilters = $TransactionTypeFilters;
            StartDate = $StartDate.ToString();
            Duration = $Duration.ToString();
            StartTransactionPrefix = $StartTransactionPrefix;
            EndTransactionPrefix = $EndTransactionPrefix;
        }
    ))

    # ⌛ 2/5 Open file
    $Encoding = [System.Text.Encoding]::GetEncoding(1251)
    $Lines = [System.IO.File]::ReadLines($Path, $Encoding)

    # ⌛ 3/5 Look for the first transaction from the specified period
    $Activity = "Looking for the first transaction within period ('$StartTransactionPrefix' - '$EndTransactionPrefix') in log file '$Path'"
    $WRITE_PROGRESS_FREQUENCY = 25000
    $LineNumber = 1
    
    foreach ($Line in $Lines) {

        # Print progress
        if ($LineNumber % $WRITE_PROGRESS_FREQUENCY -eq 0)
        {
            $Operation = "$LineNumber : $Line"
            Write-Progress -Activity $Activity -CurrentOperation $Operation -PercentComplete -1
        }

        # Determine if the first transaction from the period is found
        $AfterStart = $Line.CompareTo($StartTransactionPrefix) -ge 0

        if ($AfterStart) {
            Write-Host "First transaction of the period: '$Line'"
            break
        }

        $LineNumber++
    }

    # ⌛ 4/5 Read transactions from the period

    # Process the line which has already been read and determined as the begginning of the period
    $TransactionsFound = 0
    $TransactionsInPeriod = 1
    $Result = (Get-TransactionInfo $Line $ObjectFilters $TransactionTypeFilters)
    if (-not ($null -eq $Result)) {
        $TransactionsFound++
    }

    # Store current and previous lines 
    $PreviosLine = $Line

    foreach ($Line in $Lines) {

        # Determine if transaction is beyond the period
        $BeforeEnd = $Line.CompareTo($EndTransactionPrefix) -lt 0

        if ($BeforeEnd) {
            $Result = (Get-TransactionInfo $Line $ObjectFilters $TransactionTypeFilters)
            
            if (-not ($null -eq $Result)) {
                $TransactionsFound++

                # 📢 Write to ouput
                Write-Output $Result
            }

            $TransactionsInPeriod++
        }
        else {
            Write-Host "Last transaction of the period: '$PreviosLine'"
            break
        }

        $LineNumber++

        $PreviosLine = $Line
    }

    # ⌛ 5/5 Print stats
    Write-Host "Transactions in period: $TransactionsInPeriod"
    Write-Host "Matching transactions: $TransactionsFound"
    exit 0
}
catch {
    # ⚠️ Print error description
    Write-Host "Error in line $($_.InvocationInfo.ScriptLineNumber): $($Error[0])"
	exit 1
}