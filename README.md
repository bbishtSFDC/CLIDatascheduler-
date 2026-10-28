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