# run_LTABillImport.ps1
# Save as: C:\Dataloader\jobs\run_insert.ps1
# Run via: powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Dataloader\jobs\run_insert.ps1"
 
# ============================================================
# JOB CONFIGURATION — edit these values as needed
# ============================================================
 
# Salesforce target org alias (set during sf org login web --alias)
$orgAlias    = "dataloader-itreview"
 
# Salesforce object API name to load records into
$sfObject    = "LTA_BillImport__c"
 
# Column mappings file (SourceColumn -> SalesforceField)
$mappingFile = "C:\Dataloader\jobs\ColumnMappings.csv"
 
# ============================================================
 
$timestamp     = Get-Date -Format "yyyyMMdd_HHmmss"
 
$inputFile     = "C:\Dataloader\jobs\input\BillImport.csv"
$mappedFile    = "C:\Dataloader\jobs\temp\BillImport_mapped_$timestamp.csv"
$sfRawLog      = "C:\Dataloader\jobs\temp\sfraw_$timestamp.json"
$successFile   = "C:\Dataloader\jobs\output\success_$timestamp.csv"
$errorFile     = "C:\Dataloader\jobs\output\error_$timestamp.csv"
$processedFile = "C:\Dataloader\jobs\processed\BillImport_$timestamp.csv"
$runLog        = "C:\Dataloader\jobs\output\runlog.txt"
 
function Log($msg) {
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $msg"
    Write-Host $line
    Add-Content -Path $runLog -Value $line -Encoding utf8
}
 
# Ensure folders exist
@("C:\Dataloader\jobs\temp", "C:\Dataloader\jobs\output", "C:\Dataloader\jobs\processed") | ForEach-Object {
    if (-not (Test-Path $_)) { New-Item -ItemType Directory -Path $_ | Out-Null }
}
 
# Clean up any stale temp files from a previously interrupted run
Get-ChildItem "C:\Dataloader\jobs\temp\*" -ErrorAction SilentlyContinue | Remove-Item -Force
 
# Check for input file
if (-not (Test-Path $inputFile)) {
    Log "No input file found - skipping job"
    exit 0
}
 
Log "Input file found - starting import job"
 
# --- Step 1: Map headers ---
Log "Running MapHeaders.ps1..."
& powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Dataloader\jobs\MapHeaders.ps1" `
    -InputFile $inputFile -OutputFile $mappedFile -MappingFile $mappingFile
$mapExit = $LASTEXITCODE
 
if ($mapExit -ne 0) {
    Log "ERROR: Header mapping failed (exit $mapExit)"
    "Header mapping failed at $timestamp" | Out-File $errorFile -Encoding utf8
    exit 1
}
 
if (-not (Test-Path $mappedFile)) {
    Log "ERROR: Mapped file was not created"
    exit 1
}
 
Log "Header mapping complete. Running sf CLI import..."
 
# --- Step 2: Run bulk import, capture JSON output to temp file ---
& sf data import bulk --sobject $sfObject --file $mappedFile --target-org $orgAlias --wait 10 --json `
    | Out-File $sfRawLog -Encoding utf8
$sfExit = $LASTEXITCODE
 
Log "sf CLI exit code: $sfExit"
 
# Clean up mapped temp file immediately
if (Test-Path $mappedFile) { Remove-Item $mappedFile -Force }
 
# Parse job ID from JSON output
$jobId = $null
if (Test-Path $sfRawLog) {
    try {
        $sfJson = Get-Content $sfRawLog -Raw -Encoding utf8 | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($sfJson.result.jobId) { $jobId = $sfJson.result.jobId }
        if ($sfJson.result.id)    { $jobId = $sfJson.result.id }
        if ($sfJson.data.jobId)   { $jobId = $sfJson.data.jobId }
    } catch { }
    Remove-Item $sfRawLog -Force
}
 
Log "Job ID: $jobId"
 
# --- Step 3: Fetch per-row results ---
if ($jobId) {
    Log "Fetching per-row job results..."
 
    # sf data bulk results saves files named <jobId>-success-records.csv and <jobId>-failed-records.csv
    # in the current working directory — set location to jobs folder so files land there
    Push-Location "C:\Dataloader\jobs"
    & sf data bulk results --job-id $jobId --target-org $orgAlias | Out-Null
    $resultsExit = $LASTEXITCODE
    Pop-Location
 
    Log "sf data bulk results exit code: $resultsExit"
 
    $rawSuccess = "C:\Dataloader\jobs\$jobId-success-records.csv"
    $rawError   = "C:\Dataloader\jobs\$jobId-failed-records.csv"
 
    # Log what files were actually created to help diagnose path issues
    Log "Looking for success file: $rawSuccess  exists=$( Test-Path $rawSuccess )"
    Log "Looking for error file:   $rawError  exists=$( Test-Path $rawError )"
 
    if (Test-Path $rawSuccess) {
        Move-Item -Path $rawSuccess -Destination $successFile -Force
        Log "Success file written: $successFile"
    } else {
        Log "No successful records for this job"
    }
 
    if (Test-Path $rawError) {
        Move-Item -Path $rawError -Destination $errorFile -Force
        Log "Error file written: $errorFile"
    } else {
        Log "No failed records for this job"
    }
 
    if ($resultsExit -ne 0) {
        Log "WARNING: sf data bulk results returned exit code $resultsExit"
        if (-not (Test-Path $successFile) -and -not (Test-Path $errorFile)) {
            if ($sfExit -eq 0) {
                "Import completed at $timestamp - manual check: sf data bulk results --job-id $jobId --target-org $orgAlias" | Out-File $successFile -Encoding utf8
            } else {
                "Import failed at $timestamp - manual check: sf data bulk results --job-id $jobId --target-org $orgAlias" | Out-File $errorFile -Encoding utf8
            }
        }
    }
} else {
    Log "WARNING: Could not parse job ID from sf CLI output"
    if ($sfExit -eq 0) {
        "Import completed at $timestamp but job ID could not be parsed for row-level results" | Out-File $successFile -Encoding utf8
    } else {
        "Import failed at $timestamp (sf exit $sfExit) and job ID could not be parsed" | Out-File $errorFile -Encoding utf8
    }
}
 
# --- Step 4: Move input file to processed ---
try {
    Move-Item -Path $inputFile -Destination $processedFile -Force
    Log "File moved to processed: $processedFile"
} catch {
    Log "ERROR: File move failed - $_"
}
 
Log "Job completed (sf exit: $sfExit)"
exit $sfExit
 