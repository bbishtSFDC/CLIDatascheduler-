# Salesforce CSV Loader for Windows

This project loads CSV files from a Windows machine into Salesforce using Salesforce CLI, PowerShell, Bulk API 2.0, and Windows Task Scheduler.

Start with the [Salesforce CSV Loader Setup Guide](Salesforce%20CSV%20Loader%20Setup%20Guide.md). A [Word version](Salesforce%20CSV%20Loader%20Setup%20Guide.docx) is also included.

## Important

- The supplied scripts currently perform an insert operation.
- The object name, Salesforce org alias, input filename, field mappings, and sample data are examples from one implementation.
- Review and update `run_insert.ps1` and `ColumnMappings.csv` before using the loader.
- `BillImport_sample.csv` and `BillImport_bulk_sample.csv` are examples only. Do not treat them as production-ready templates.
- Test with a small synthetic file in a Salesforce sandbox before scheduling production loads.

## Package

- `Dataloader/jobs/`: editable scripts, mappings, and samples
- `Dataloader/jobs.zip`: Windows deployment archive
- `Salesforce CSV Loader Setup Guide.md`: installation and operations guide
- `Salesforce CSV Loader Setup Guide.docx`: distributable Word guide

The implementation scripts have been retained unchanged. See the guide for configuration, installation, Task Scheduler setup, security, troubleshooting, and known limitations.

## Using a different operation (insert, upsert, delete)

The package as supplied does **insert**. To use it for another operation, change the places below. Everything else (folders, `MapHeaders.ps1`, Task Scheduler, result handling) stays the same.

Run `sf data upsert bulk --help` or `sf data delete bulk --help` on your installed CLI first, because flags can differ between CLI versions. Test every change in a sandbox with a few synthetic records before scheduling it.

| Operation | Use this as is? | What to change |
|---|---|---|
| **Insert** | Yes | Nothing beyond the normal configuration in the setup guide. |
| **Upsert** | No | `run_insert.ps1` (2 edits), `ColumnMappings.csv`, and a Salesforce External ID field. |
| **Delete** | No | `run_insert.ps1` (1 edit) and the input file layout. |

### Upsert

Upsert updates a record when the External ID matches, and inserts it when it doesn't.

1. **Salesforce:** make sure the object has a field marked **External ID**. Give the integration user Edit access to the object and Edit field-level access to the fields being updated, not only Create.
2. **`ColumnMappings.csv`:** add a mapping for your External ID column, for example `External Customer ID,External_Customer_ID__c`. Every row in the input file must have a value in that column.
3. **`run_insert.ps1`, configuration block:** add the External ID field API name.
   ```powershell
   $externalIdField = "External_Customer_ID__c"
   ```
4. **`run_insert.ps1`, Step 2:** replace the import command.
   ```powershell
   # Insert (supplied)
   & sf data import bulk --sobject $sfObject --file $mappedFile --target-org $orgAlias --wait 10 --json | Out-File $sfRawLog -Encoding utf8

   # Upsert
   & sf data upsert bulk --sobject $sfObject --file $mappedFile --external-id $externalIdField --target-org $orgAlias --wait 10 --json | Out-File $sfRawLog -Encoding utf8
   ```
5. **Optional:** copy the files to `run_upsert.ps1` and `run_upsert.bat`, and point the `.bat` file and the Task Scheduler action at the new names, so operators can tell the jobs apart.

Notes:
- Empty cells do not normally clear existing values in a bulk upsert. Test this in a sandbox if you need blanks to overwrite.
- Two rows with the same External ID in one file can cause errors or an unexpected final value. De-duplicate the source.
- Re-running the same file is much safer than with insert, because it should not create duplicates.

### Delete

Delete removes records, so test with extreme care. Deleted records normally go to the Recycle Bin. A hard delete is a separate permission and cannot be undone.

1. **Salesforce:** give the integration user Delete access

   ## Benefits

- **Automates recurring CSV loads** into Salesforce, so nobody runs Data Loader by hand.
- **No extra licences or middleware.** It uses Salesforce CLI, PowerShell and Windows Task Scheduler.
- **Quick to set up.** Extract, authorize, configure the object and mappings, then schedule.
- **Reusable.** Change the org alias, object and column mappings to load a different object or org.
- **Auditable.** Every run keeps a log, row-level success and failure files, and the archived input.
- **Secure by design.** It uses OAuth through Salesforce CLI. It does not use SOAP API login, and no passwords or tokens are stored in the scripts.
- **Flexible.** Insert is supplied. See "Using a different operation" for upsert and delete.

Not suited to real-time integrations, or to pipelines that need guaranteed delivery and automatic retries.
