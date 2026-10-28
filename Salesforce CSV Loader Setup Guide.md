# Salesforce CSV Loader — Windows Setup and Operations Guide

## Purpose

This package loads a CSV file from a Windows machine into a Salesforce object by using Salesforce CLI, PowerShell, Bulk API 2.0, and Windows Task Scheduler.

The included scripts currently perform an **insert** operation. They are a reusable template, but the values supplied with the package are examples from one implementation. Before using the loader with another Salesforce object, review and update the organization alias, object API name, input file, and field mappings described in this guide.

## Important: sample files are examples

The following files demonstrate the expected format only:

- `BillImport_sample.csv`
- `BillImport_bulk_sample.csv`
- `ColumnMappings.csv`

Do not assume their columns, field names, or sample values match your Salesforce org.

- The sample CSV files contain fictional legislative-style records. Replace them with your own test data.
- `ColumnMappings.csv` contains example mappings for a specific custom object. Replace its rows with mappings for your source file and Salesforce object.
- Test with a small, non-production file in a Salesforce sandbox before scheduling a production load.
- Do not place production secrets, access tokens, or real confidential data in sample files.

## How the loader works

1. Windows Task Scheduler starts `run_insert.bat`.
2. The batch file starts `run_insert.ps1`.
3. The PowerShell script looks for `C:\Dataloader\jobs\input\BillImport.csv`.
4. `MapHeaders.ps1` reads `ColumnMappings.csv` and changes source headers to Salesforce field API names.
5. Salesforce CLI submits the mapped CSV as a bulk insert.
6. The script requests row-level success and failure results.
7. Output is written under `output`, and the original input is moved to `processed`.

The package does not use Salesforce Data Loader Desktop or a Data Loader JAR. It uses the `sf` command-line interface.

## Package contents

Copy the contents of the supplied `jobs.zip` archive to `C:\Dataloader\jobs`.

Expected layout:

```text
C:\Dataloader\
  jobs\
    run_insert.bat
    run_insert.ps1
    MapHeaders.ps1
    ColumnMappings.csv
    BillImport_sample.csv
    BillImport_bulk_sample.csv
    input\
    output\
    processed\
    temp\
```

Runtime files:

- `input\BillImport.csv`: file waiting to be loaded
- `output\success_YYYYMMDD_HHMMSS.csv`: successful row results
- `output\error_YYYYMMDD_HHMMSS.csv`: failed row results or job errors
- `output\runlog.txt`: timestamped run history
- `processed\BillImport_YYYYMMDD_HHMMSS.csv`: archived input
- `temp\`: temporary mapped CSV and Salesforce CLI response files

## Prerequisites

### Windows

- A currently supported Windows desktop or Windows Server release
- Permission to install Salesforce CLI
- Permission to create and run a Windows scheduled task
- A dedicated Windows account is recommended for scheduled operation

### Salesforce

Use a dedicated integration user or another account approved by your Salesforce administrator. It needs:

- API access
- Create access to the target object
- Read and Edit field-level access for every field being loaded
- Access to required record types and referenced records, when applicable
- Any permissions required by validation rules, flows, triggers, and other automation

Apply least privilege. License availability, password policy, MFA, login hours, IP restrictions, connected-app policy, and refresh-token lifetime vary by organization. Confirm them with your Salesforce security administrator.

## Step 1: Install Salesforce CLI

Download Salesforce CLI from the official Salesforce CLI page:

https://developer.salesforce.com/tools/salesforcecli

After installation, open a new Command Prompt and run:

```bat
sf --version
```

If Windows reports that `sf` is not recognized, close and reopen Command Prompt. If it still fails, confirm that Salesforce CLI is installed and available on the `PATH` of the Windows account that will run the scheduled task.

## Step 2: Create the folders and copy the package

Create the folders:

```bat
mkdir "C:\Dataloader\jobs\input"
mkdir "C:\Dataloader\jobs\output"
mkdir "C:\Dataloader\jobs\processed"
mkdir "C:\Dataloader\jobs\temp"
```

Extract `jobs.zip`, then copy its job files and folders into:

```text
C:\Dataloader\jobs
```

The supplied scripts use this exact path. Installing elsewhere requires changing every `C:\Dataloader\jobs` reference in `run_insert.ps1`, `MapHeaders.ps1`, and `run_insert.bat`.

## Step 3: Authorize Salesforce CLI

Choose a short alias for the target org, such as `loader-sandbox` or `loader-production`.

For a sandbox or My Domain login, use the correct organization URL:

```bat
sf org login web --instance-url https://your-domain--sandbox-name.sandbox.my.salesforce.com --alias loader-sandbox
```

For production, use the organization’s approved login or My Domain URL:

```bat
sf org login web --instance-url https://your-domain.my.salesforce.com --alias loader-production
```

A browser opens for the normal Salesforce authorization flow. Complete any login, MFA, or approval steps required by the organization.

Verify the connection:

```bat
sf org display --target-org loader-sandbox
```

Important:

- Perform authorization while signed in to the same Windows account that will run the scheduled task.
- Salesforce CLI stores authorization using its supported local credential mechanisms. Protect the Windows account and machine.
- Authorization can stop working after revocation, user deactivation, connected-app policy changes, session-policy changes, or other security changes.
- Do not document or copy Salesforce CLI credential files as a backup method. Reauthorize through the supported login flow when required.

## Step 4: Configure the target org and object

Open:

```text
C:\Dataloader\jobs\run_insert.ps1
```

Update the configuration block near the top.

### Organization alias

Set `$orgAlias` to the exact alias used during `sf org login web`:

```powershell
$orgAlias = "loader-sandbox"
```

Confirm aliases with:

```bat
sf org list
```

### Salesforce object API name

Set `$sfObject` to the target object's **API name**, not its display label:

```powershell
$sfObject = "Your_Object__c"
```

Examples:

- Standard Account object: `Account`
- Standard Contact object: `Contact`
- Custom object labeled “Import Record”: `Import_Record__c`

Find the API name in Salesforce Setup:

1. Open **Setup**.
2. Open **Object Manager**.
3. Select the object.
4. Copy the **API Name** from the object details.

Do not use the object label if it differs from the API name.

### Mapping file location

The default is:

```powershell
$mappingFile = "C:\Dataloader\jobs\ColumnMappings.csv"
```

Leave this unchanged when using the standard package layout. If the mapping filename or folder changes, update this value.

### Input filename

The current script requires:

```text
C:\Dataloader\jobs\input\BillImport.csv
```

The name is case-insensitive on standard Windows file systems, but the complete filename must otherwise match.

To use a different filename, update these values in `run_insert.ps1`:

- `$inputFile`
- `$mappedFile` if a different temporary name is desired
- `$processedFile` if a different archive name is desired

Changing only the name of a sample file does not change what the script looks for.

## Step 5: Configure field mappings

Open:

```text
C:\Dataloader\jobs\ColumnMappings.csv
```

It has two columns:

```csv
SourceColumn,SalesforceField
Customer Name,Name
External Customer ID,External_Customer_ID__c
Status,Status__c
```

### SourceColumn

`SourceColumn` must exactly match a header in the incoming CSV after surrounding quote characters and whitespace are removed.

Example incoming header:

```csv
Customer Name,External Customer ID,Status
```

### SalesforceField

`SalesforceField` must be the Salesforce field **API name**.

Examples:

- Standard field labeled “Account Name”: `Name`
- Standard field labeled “Phone”: `Phone`
- Custom field labeled “External Customer ID”: `External_Customer_ID__c`

Find field API names in Salesforce:

1. Open **Setup**.
2. Open **Object Manager**.
3. Select the target object.
4. Open **Fields & Relationships**.
5. Copy each value from the **Field Name** or API name column.

### Mapping rules

- Include one mapping row for each source header that is not already a valid Salesforce field API name.
- Do not map two source columns to the same Salesforce field.
- Do not include blank mapping rows.
- Preserve the header row `SourceColumn,SalesforceField`.
- If an incoming header has no mapping, the script leaves it unchanged. The load succeeds only if that unchanged header is already a valid field API name accepted by Salesforce.
- Remove mappings for columns that do not exist in your input.
- Add all required target fields unless Salesforce supplies them through defaults or automation.
- Relationship fields, record type IDs, dates, date/times, numbers, booleans, and picklists must use values accepted by the target Salesforce field.

After changing the target object, review **every row** in `ColumnMappings.csv`. Object and field API names are independent settings: changing `$sfObject` does not automatically change any field mappings.

## Step 6: Prepare and test the input

Use the included sample files only to understand the format. Create a new CSV for the target object.

Requirements:

- Save as CSV, not XLSX.
- Use UTF-8 encoding, with or without a UTF-8 BOM.
- Put field names in the first row.
- Use a comma as the delimiter.
- Save the runtime file as `C:\Dataloader\jobs\input\BillImport.csv`, unless the script was updated for another name.
- Ensure every value is valid for its mapped Salesforce field.

Recommended first test:

1. Use a Salesforce sandbox.
2. Include one to five synthetic records.
3. Use unique values so the test records are easy to find and remove.
4. Run the job manually.
5. Review both the output files and the created Salesforce records.

Do not use `BillImport_bulk_sample.csv` as production input. It is a volume/example file, not a template guaranteed to match another object.

## Step 7: Run manually before scheduling

From Command Prompt:

```bat
cd /d C:\Dataloader\jobs
run_insert.bat
```

Review:

```text
C:\Dataloader\jobs\output\runlog.txt
```

Then check for:

- `success_TIMESTAMP.csv`
- `error_TIMESTAMP.csv`
- the archived input under `processed`

Confirm the records in Salesforce. Do not configure a recurring schedule until the manual test works with the same Windows account intended for Task Scheduler.

## Step 8: Configure Windows Task Scheduler

1. Press **Win + R**.
2. Enter `taskschd.msc`.
3. Select **Create Task**.

### General

- Name: `Salesforce CSV Loader - <job name>`
- Select **Run whether user is logged on or not**.
- Use the same Windows account that authorized Salesforce CLI.
- Select **Run with highest privileges** only if required by local policy and folder permissions.
- Select the applicable Windows version.

### Triggers

Create the required schedule and keep **Enabled** selected.

### Actions

- Action: **Start a program**
- Program/script: `C:\Dataloader\jobs\run_insert.bat`
- Start in: `C:\Dataloader\jobs`

### Settings

- If the task is already running: **Do not start a new instance**
- Stop the task if it runs longer than an organization-approved limit, such as one hour.
- Enable retry behavior only after considering whether the source system can safely submit the same data again.

Save the task and supply the Windows account credentials when prompted.

Use **Run** in Task Scheduler for the first scheduled-account test. Review **Last Run Result** and `output\runlog.txt`.

## Daily operation

1. Confirm no previous `BillImport.csv` remains in `input`.
2. Copy the new file to `input\BillImport.csv`.
3. Wait for the schedule or start the task manually.
4. Review `runlog.txt` and row-level result files.
5. Reconcile successful and failed row counts with the source file.
6. Correct failed records and reload them only after confirming they were not inserted.

The current script moves the input file to `processed` after the Salesforce CLI command, including some failure scenarios. Therefore, the presence of a file under `processed` does **not** by itself prove that all rows loaded successfully. Always inspect the output and Salesforce records.

## Changing the loader for another object

Use this checklist:

1. Confirm the integration user can create records on the new object.
2. Change `$sfObject` in `run_insert.ps1`.
3. Replace all rows in `ColumnMappings.csv` with mappings for the new source and object.
4. Create a new small sample input with the new source headers.
5. Save the test input using the filename expected by `$inputFile`.
6. Run manually in a sandbox.
7. Review row-level results and Salesforce automation behavior.
8. Update the scheduled task name and operational documentation so operators know which object the job loads.

## Changing to another Salesforce org

1. Authorize the new org with a new alias.
2. Verify it with `sf org display --target-org <alias>`.
3. Change `$orgAlias` in `run_insert.ps1`.
4. Confirm the target object and every mapped field exist in that org.
5. Confirm the integration user has the required permissions.
6. Run a small sandbox test before production.

Never assume that objects, fields, picklist values, record types, validation rules, or automation are identical between Salesforce orgs.

## Troubleshooting

### `sf` command not found

- Run `sf --version` as the same Windows account used by Task Scheduler.
- Reopen Command Prompt after installation.
- Confirm Salesforce CLI is on that account's `PATH`.

### Target org is not connected

Run:

```bat
sf org display --target-org <alias>
```

If authorization is invalid, repeat the approved `sf org login web` flow using the scheduled-task Windows account.

### No input file found

Confirm the file is exactly:

```text
C:\Dataloader\jobs\input\BillImport.csv
```

Also confirm the scheduled task runs with permission to read that folder.

### `INVALID_TYPE` or object not found

- Confirm `$sfObject` uses the object API name.
- Confirm the object exists in the target org.
- Confirm the user has object access.

### `INVALID_FIELD` or field not found

- Review the generated headers and `ColumnMappings.csv`.
- Use field API names, including `__c` for custom fields.
- Confirm fields exist on the configured object and in the configured org.

### `REQUIRED_FIELD_MISSING`

Add the required source column and mapping, or confirm that Salesforce automation/defaults supply the value.

### `FIELD_INTEGRITY_EXCEPTION`

Check picklist values, lookup IDs, record type IDs, formats, field lengths, and other field constraints.

### Validation rule, flow, or trigger error

The integration user is subject to Salesforce automation unless the organization has explicitly designed an approved bypass. Review the row's `sf__Error` value with the object owner or Salesforce administrator.

### Task works manually but not on schedule

- Confirm Task Scheduler uses the same Windows account that ran `sf org login web`.
- Set **Start in** to `C:\Dataloader\jobs`.
- Confirm that account can run PowerShell, locate `sf`, and read/write all job folders.
- Review Task Scheduler History, Last Run Result, and `output\runlog.txt`.

### No row-level result files

Review `runlog.txt` for the Salesforce job ID and CLI exit code. If a job ID is available, an administrator can inspect it with the installed CLI version's supported bulk status/results commands.

## Security and maintenance

- Restrict NTFS permissions on `C:\Dataloader` to administrators, the scheduled-task account, and approved operators.
- Treat input, processed, success, error, and log files as Salesforce data.
- Define retention and secure deletion rules for local files.
- Monitor the integration user and scheduled task.
- Keep Salesforce CLI on a tested, supported release.
- Re-test after Salesforce metadata, validation, automation, security, CLI, Windows, or script changes.
- Reauthorize when required by organization policy; do not assume refresh tokens are permanent.
- Do not email or publish production CSVs, logs, result files, usernames, org URLs, or credential material.

## Current template limitations

The supplied scripts are intentionally unchanged. Operators and administrators should understand these limitations:

- The operation is insert only.
- Paths are fixed to `C:\Dataloader\jobs`.
- The input filename is fixed to `BillImport.csv`.
- The supplied object, alias, mappings, and samples are examples that must be reviewed.
- Header processing is designed for the included comma-separated format.
- Input can be archived even when the overall load is not fully successful.
- Temporary files are cleared at the start of a run.
- There is no installer or automatic scheduled-task creation.

If these limitations do not meet the organization's operational or security requirements, have the scripts reviewed and enhanced before production use.

