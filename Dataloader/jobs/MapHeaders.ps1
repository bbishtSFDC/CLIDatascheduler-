param(
    [string]$InputFile,
    [string]$OutputFile,
    [string]$MappingFile = "C:\Dataloader\jobs\ColumnMappings.csv"
)

# Read file as bytes first to strip BOM if present
$bytes = [System.IO.File]::ReadAllBytes($InputFile)

# Strip UTF-8 BOM (EF BB BF) if present
if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
    $bytes = $bytes[3..($bytes.Length - 1)]
}

$content = [System.Text.Encoding]::UTF8.GetString($bytes)
$lines = $content -split "`r`n|`n|`r"

if ($lines.Count -eq 0) {
    Write-Error "Input file is empty"
    exit 1
}

$header = $lines[0]

# Load column mappings from external CSV file (SourceColumn -> SalesforceField)
# To add or change a mapping: edit C:\Dataloader\jobs\ColumnMappings.csv in Excel or Notepad
if (-not (Test-Path $MappingFile)) {
    Write-Error "Mapping file not found: $MappingFile"
    exit 1
}

$mappings = [ordered]@{}
Import-Csv $MappingFile | ForEach-Object {
    $mappings[$_.SourceColumn] = $_.SalesforceField
}

# Split header into individual column names and apply mappings
$cols = $header -split ','

$newCols = @()
foreach ($col in $cols) {
    $trimmed = $col.Trim().Trim('"')
    if ($mappings.Contains($trimmed)) {
        $newCols += $mappings[$trimmed]
    } else {
        $newCols += $col
    }
}

$lines[0] = $newCols -join ','

# Write output without BOM
$newContent = $lines -join "`r`n"
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($OutputFile, $newContent, $utf8NoBom)

Write-Host "Header mapping complete. Columns mapped: $($mappings.Count)"
