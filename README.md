# Merge-CSVFile

[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Windows%2010%2F11-blue)]

**[English](README.md) · [Français](README.fr.md)**

PowerShell script for merging two CSV files, offering two merge modes (stacking or
key-based join), configurable deduplication, export of unmatched records, and optional
logging.

## Table of contents

- [Overview](#overview)
- [Requirements](#requirements)
- [Installation](#installation)
- [Concepts](#concepts)
- [Syntax](#syntax)
- [Parameters](#parameters)
- [Detailed examples](#detailed-examples)
- [Output files](#output-files)
- [Exit codes](#exit-codes)
- [Logging](#logging)
- [Known limitations](#known-limitations)

## Overview

`Merge-CSVFile.ps1` merges two CSV files using one of the following two modes:

- **Union**: stacks the rows of both files, unifying their columns.
- **Join**: combines, on a single row, the columns of records that share a common key.

The script also handles result deduplication, traceability of each row's origin,
per-file column separators, and a key comparison that is case-insensitive by default.
It has no external module dependency.

## Requirements

- Windows PowerShell 5.1 or PowerShell 7 and later.
- No additional module is required.
- Input files must include a header row (column names).

## Installation

The script is self-contained. Simply download `Merge-CSVFile.ps1` and run it from a
PowerShell console.

Depending on the execution policy in effect on the machine, you may need to allow the
script to run for the current session:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

## Concepts

### Merge modes

| Mode | Operation | Effect |
|------|-----------|--------|
| `Union` | Stacking | Appends the rows of both files one after another. All columns are unified; a row receives an empty value for columns it does not have. |
| `Join` | Join | Matches records that share a common key value and combines their columns onto a single row. |

Stacking acts on **rows**, whereas a join combines **columns**. The choice of mode depends
on the desired result, regardless of the structure of the source files.

### Join behavior

In `Join` mode, the `-JoinType` parameter determines how records from file 1 with no match
in file 2 are handled:

| Value | Behavior |
|-------|----------|
| `KeepUnmatched` (default) | Keeps all rows from file 1. The columns from file 2 remain empty when there is no match. |
| `MatchedOnly` | Keeps only the rows that have a match in both files. |

When the same column (other than the key) exists in both files, its handling depends on the
`-ColumnConflict` parameter:

| Value | Behavior |
|-------|----------|
| `Suffix` (default) | Both versions are kept, suffixed with `_F1` and `_F2`. |
| `PreferF1` | A single column is kept, favoring the value from file 1. |
| `PreferF2` | A single column is kept, favoring the value from file 2. |

With `PreferF1` or `PreferF2`, the `-ConflictEmptyValue` parameter determines the behavior
when the preferred value is empty (a null string or one made up only of spaces):

| Value | Behavior |
|-------|----------|
| `Strict` (default) | The preferred value is kept, even when empty. |
| `Fallback` | The value from the other file is used when the preferred value is empty. |

Key comparison is **case-insensitive by default** (`PC-01` is equivalent to `pc-01`), in
line with the behavior of Active Directory for computer names. The `-CaseSensitiveKey`
switch enforces a case-sensitive comparison.

### Deduplication

Deduplication keeps a single occurrence per key, according to the chosen strategy:

| Strategy | Behavior |
|----------|----------|
| `None` (default) | No deduplication. |
| `KeepFirst` | Keeps the first occurrence encountered. |
| `KeepLast` | Keeps the last occurrence encountered. |

The deduplication key is determined as follows:

1. If `-DeduplicateColumn` is provided, the designated column is used as the key.
2. Otherwise, in `Join` mode, the key from file 1 is used.
3. Otherwise, in `Union` mode, deduplication is based on the entire row (concatenation of
   all columns).

The reference order (KeepFirst/KeepLast) corresponds to the order in which rows appear in
the source files.

## Syntax

Union mode:

```powershell
Merge-CSVFile.ps1 -Union -InputCSV1 <path> -InputCSV2 <path> -OutputPath <folder>
                  [-StrictSchema]
                  [-Deduplicate <None|KeepFirst|KeepLast>] [-DeduplicateColumn <name>]
                  [-AddSourceFileInfo]
                  [-InputDelimiter1 <char>] [-InputDelimiter2 <char>] [-OutputDelimiter <char>]
                  [-OutputLog <folder>]
```

Join mode:

```powershell
Merge-CSVFile.ps1 -Join -InputCSV1 <path> -InputCSV2 <path> -OutputPath <folder>
                  -KeyFile1 <name> -KeyFile2 <name>
                  [-JoinType <KeepUnmatched|MatchedOnly>] [-CaseSensitiveKey]
                  [-ColumnConflict <Suffix|PreferF1|PreferF2>]
                  [-ConflictEmptyValue <Strict|Fallback>]
                  [-NoMatchOutputPath <folder>]
                  [-Deduplicate <None|KeepFirst|KeepLast>] [-DeduplicateColumn <name>]
                  [-AddSourceFileInfo]
                  [-InputDelimiter1 <char>] [-InputDelimiter2 <char>] [-OutputDelimiter <char>]
                  [-OutputLog <folder>]
```

The mode is selected by the `-Union` or `-Join` switch, which are mutually exclusive.
The parameters specific to Join mode (`-KeyFile1`, `-KeyFile2`, `-JoinType`,
`-CaseSensitiveKey`, `-ColumnConflict`, `-ConflictEmptyValue`, `-NoMatchOutputPath`) are
accepted only with `-Join`. Likewise, `-StrictSchema` is accepted only with `-Union`. This
restriction is enforced by the parameter sets and reported by PowerShell in case of
incorrect usage.

## Parameters

| Parameter | Mode | Required | Default | Description |
|-----------|------|:--------:|---------|-------------|
| `-Union` | — | Yes (or `-Join`) | — | Selects stacking mode. |
| `-Join` | — | Yes (or `-Union`) | — | Selects join mode. |
| `-InputCSV1` | Union / Join | Yes | — | Path to the first CSV file. |
| `-InputCSV2` | Union / Join | Yes | — | Path to the second CSV file. |
| `-OutputPath` | Union / Join | Yes | — | Destination folder for the merged file. Created if it does not exist. |
| `-KeyFile1` | Join | Yes | — | Name of the key column in file 1. |
| `-KeyFile2` | Join | Yes | — | Name of the key column in file 2. |
| `-JoinType` | Join | No | `KeepUnmatched` | Handling of unmatched records from file 1. |
| `-ColumnConflict` | Join | No | `Suffix` | Handling of conflicting columns: `Suffix`, `PreferF1`, `PreferF2`. |
| `-ConflictEmptyValue` | Join | No | `Strict` | With `PreferF1`/`PreferF2`, handling of an empty preferred value: `Strict` or `Fallback`. |
| `-CaseSensitiveKey` | Join | No | (case-insensitive) | Makes the key comparison case-sensitive. |
| `-NoMatchOutputPath` | Join | No | — | Export folder for unmatched records. |
| `-StrictSchema` | Union | No | (disabled) | Requires strictly identical columns between the two files. |
| `-Deduplicate` | Union / Join | No | `None` | Deduplication strategy: `None`, `KeepFirst`, `KeepLast`. |
| `-DeduplicateColumn` | Union / Join | No | — | Column used as the deduplication key. |
| `-AddSourceFileInfo` | Union / Join | No | (disabled) | Adds the traceability columns `SourceFileF1` and `SourceFileF2`. |
| `-InputDelimiter1` | Union / Join | No | `;` | Column separator for file 1. |
| `-InputDelimiter2` | Union / Join | No | `;` | Column separator for file 2. |
| `-OutputDelimiter` | Union / Join | No | `;` | Column separator for the output files. |
| `-OutputLog` | Union / Join | No | — | Destination folder for the execution log. |

## Detailed examples

The examples below use the `;` separator (default value). The result of each command is
shown afterwards.

### Example 1 — Simple stacking

Concatenate two inventory collections from two sites, keeping all records.

`inventory-site-a.csv`:

```
ComputerName;OS;EvaluationDate
PC-01;Windows 11;2026/05/20 10:00:00
PC-02;Windows 10;2026/05/20 10:05:00
```

`inventory-site-b.csv`:

```
ComputerName;OS;EvaluationDate
PC-03;Windows 11;2026/05/21 09:00:00
PC-01;Windows 11;2026/05/21 09:02:00
```

```powershell
.\Merge-CSVFile.ps1 -Union `
    -InputCSV1 "C:\Data\inventory-site-a.csv" `
    -InputCSV2 "C:\Data\inventory-site-b.csv" `
    -OutputPath "C:\Reports"
```

Result:

```
ComputerName;OS;EvaluationDate
PC-01;Windows 11;2026/05/20 10:00:00
PC-02;Windows 10;2026/05/20 10:05:00
PC-03;Windows 11;2026/05/21 09:00:00
PC-01;Windows 11;2026/05/21 09:02:00
```

### Example 2 — Stacking with per-machine deduplication

Keep a single row per `ComputerName` value. The two occurrences of PC-01, although distinct
by their date, are matched on the `ComputerName` column alone.

```powershell
.\Merge-CSVFile.ps1 -Union `
    -InputCSV1 "C:\Data\inventory-site-a.csv" `
    -InputCSV2 "C:\Data\inventory-site-b.csv" `
    -Deduplicate KeepFirst -DeduplicateColumn "ComputerName" `
    -OutputPath "C:\Reports"
```

Result (the `KeepFirst` strategy keeps the first occurrence of PC-01):

```
ComputerName;OS;EvaluationDate
PC-01;Windows 11;2026/05/20 10:00:00
PC-02;Windows 10;2026/05/20 10:05:00
PC-03;Windows 11;2026/05/21 09:00:00
```

Without `-DeduplicateColumn`, deduplication would apply to the entire row; since the two
PC-01 rows differ, both would be kept.

### Example 3 — Strict stacking

Stack two files expected to be homogeneous, stopping the process if their columns differ.

```powershell
.\Merge-CSVFile.ps1 -Union -StrictSchema `
    -InputCSV1 "C:\Data\inventory-site-a.csv" `
    -InputCSV2 "C:\Data\inventory-site-b.csv" `
    -OutputPath "C:\Reports"
```

With the files from Example 1 (identical columns), the result is that of Example 1. If a
column differs between the two files, the script stops with exit code `2` and logs the
columns present in only one of the two files.

### Example 4 — Join on keys with different names

Cross a technical inventory with a directory export to produce a consolidated view per
machine. The key is named `ComputerName` in the first file and `Name` in the second.

`inventory.csv`:

```
ComputerName;OS;SecureBoot
PC-01;Windows 11;True
PC-02;Windows 10;False
```

`ad.csv`:

```
Name;OU;LastLogon
PC-01;OU=Paris;2026/05/20
PC-03;OU=Lyon;2026/05/19
```

```powershell
.\Merge-CSVFile.ps1 -Join `
    -InputCSV1 "C:\Data\inventory.csv" `
    -InputCSV2 "C:\Data\ad.csv" `
    -KeyFile1 "ComputerName" -KeyFile2 "Name" `
    -JoinType KeepUnmatched `
    -OutputPath "C:\Reports"
```

Result:

```
ComputerName;OS;SecureBoot;OU;LastLogon
PC-01;Windows 11;True;OU=Paris;2026/05/20
PC-02;Windows 10;False;;
```

- PC-01, present in both files, has its columns combined.
- PC-02, specific to file 1, is kept (`KeepUnmatched`) with empty F2 columns.
- PC-03, specific to file 2, does not appear in the main result. It can be recovered via
  `-NoMatchOutputPath` (see Example 5).

The key from file 2 (`Name`) is not carried over: the `ComputerName` column serves as the
reference.

### Example 4b — Merging conflicting columns with priority

Consider two files sharing an `OS` column (in addition to the key) with diverging values.
The goal is to obtain a single `OS` column rather than `OS_F1` and `OS_F2`.

`inventory.csv`:

```
ComputerName;OS
PC-01;Windows 11
PC-02;
```

`reference.csv`:

```
ComputerName;OS;IP
PC-01;Windows 10;192.168.1.10
PC-02;Windows 10;192.168.1.20
```

Command with priority given to file 1 and a fallback to file 2 when the file 1 value is
empty:

```powershell
.\Merge-CSVFile.ps1 -Join `
    -InputCSV1 "C:\Data\inventory.csv" `
    -InputCSV2 "C:\Data\reference.csv" `
    -KeyFile1 "ComputerName" -KeyFile2 "ComputerName" `
    -ColumnConflict PreferF1 -ConflictEmptyValue Fallback `
    -OutputPath "C:\Reports"
```

Result:

```
ComputerName;OS;IP
PC-01;Windows 11;192.168.1.10
PC-02;Windows 10;192.168.1.20
```

- PC-01: the `OS` value from file 1 (`Windows 11`) is kept, as it is not empty.
- PC-02: since the `OS` value from file 1 is empty, the fallback provides the file 2 value
  (`Windows 10`).

With `-ConflictEmptyValue Strict`, the `OS` column for PC-02 would have remained empty.

### Example 5 — Restricted join with export of mismatches and traceability

Keep only the machines present in both files, export unmatched records separately, and
trace the origin file of each row. This example reuses the `inventory.csv` and `ad.csv`
files from Example 4.

```powershell
.\Merge-CSVFile.ps1 -Join `
    -InputCSV1 "C:\Data\inventory.csv" `
    -InputCSV2 "C:\Data\ad.csv" `
    -KeyFile1 "ComputerName" -KeyFile2 "Name" `
    -JoinType MatchedOnly `
    -NoMatchOutputPath "C:\Reports\Mismatches" `
    -AddSourceFileInfo `
    -OutputPath "C:\Reports"
```

Main file `MergedCSV_<timestamp>.csv` (only PC-01 is present in both files):

```
ComputerName;OS;SecureBoot;OU;LastLogon;SourceFileF1;SourceFileF2
PC-01;Windows 11;True;OU=Paris;2026/05/20;C:\Data\inventory.csv;C:\Data\ad.csv
```

File `Mismatches\MergedCSV_<timestamp>_NoMatchF1.csv` (present in file 1 only):

```
ComputerName;OS;SecureBoot
PC-02;Windows 10;False
```

File `Mismatches\MergedCSV_<timestamp>_NoMatchF2.csv` (present in file 2 only):

```
Name;OU;LastLogon
PC-03;OU=Lyon;2026/05/19
```

The `SourceFileF1` and `SourceFileF2` columns of the main file indicate the full path of
the origin files.

### Example 6 — Files with different separators

Merge a comma-separated file with a semicolon-separated file, producing a semicolon-separated
output.

`third-party-export.csv` (comma separator, key `Hostname`):

```
Hostname,Location
PC-01,Office 12
PC-02,Office 14
```

`inventory.csv` (semicolon separator, key `ComputerName`):

```
ComputerName;OS;SecureBoot
PC-01;Windows 11;True
PC-02;Windows 10;False
```

```powershell
.\Merge-CSVFile.ps1 -Join `
    -InputCSV1 "C:\Data\third-party-export.csv" -InputDelimiter1 "," `
    -InputCSV2 "C:\Data\inventory.csv" -InputDelimiter2 ";" `
    -OutputDelimiter ";" `
    -KeyFile1 "Hostname" -KeyFile2 "ComputerName" `
    -OutputPath "C:\Reports"
```

Result (semicolon-separated output; the `Hostname` key from file 1 serves as the reference):

```
Hostname;Location;OS;SecureBoot
PC-01;Office 12;Windows 11;True
PC-02;Office 14;Windows 10;False
```

## Output files

| File | Condition | Description |
|------|-----------|-------------|
| `MergedCSV_<timestamp>.csv` | Always | Merge result, in `-OutputPath`. |
| `MergedCSV_<timestamp>_NoMatchF1.csv` | Join mode with `-NoMatchOutputPath` | Records from file 1 with no match. |
| `MergedCSV_<timestamp>_NoMatchF2.csv` | Join mode with `-NoMatchOutputPath` | Records from file 2 with no match. |
| `Merge-CSVFile_<machine>_<timestamp>.log` | With `-OutputLog` | Execution log. |

The timestamp follows the `yyyyMMdd-HHmmss` format. The mismatch files are always created
when `-NoMatchOutputPath` is provided, including when they are empty, to confirm that the
processing actually took place.

## Exit codes

| Code | Meaning |
|:----:|---------|
| `0` | Success. |
| `1` | Output folder inaccessible. |
| `2` | Input file not found, or schemas incompatible with `-StrictSchema`. |
| `3` | Error reading the CSV files. |
| `4` | Failure writing the merged file. |
| `99` | Unhandled general error. |

These codes allow the script to be integrated into an automation chain (scheduled task,
pipeline) with result checking.

## Logging

When `-OutputLog` is provided, a timestamped log is produced in the specified folder. Each
entry follows this format:

```
[yyyy-MM-dd HH:mm:ss] [LEVEL  ] Message
```

The available levels are `DEBUG`, `INFO`, `WARNING`, and `ERROR`. Without `-OutputLog`, no
log is generated and execution remains silent. A failure to write the log does not interrupt
the processing.

## Known limitations

- **Column detection.** Column names are determined from the first row of each file.
  Well-formed CSV files have the same columns on every row; an irregular file is not
  supported.
- **Multiple matches in a join.** If a key value in file 1 matches several rows in file 2,
  the merge produces as many output rows (behavior equivalent to a standard relational join).
- **Separator consistency.** The separator declared for a file must match its actual content.
  An incorrect separator leads to incorrect column parsing.
- **Volume.** In Join mode, file 2 is indexed in memory. The processing is suitable for
  common volumes; very large files (several hundred thousand rows) call for vigilance
  regarding memory consumption.
- **Prioritized merge and unmatched rows.** When a row from file 1 has no match in file 2,
  the value preferred by `-ColumnConflict PreferF2` does not exist. With `-ConflictEmptyValue
  Strict`, the merged column therefore remains empty. The `Fallback` mode corrects this
  behavior by taking the value from file 1.

---

## License

Distributed under the **MIT** license. See the [LICENSE](LICENSE) file for more details.

---

© 2026 [Letalys](https://github.com/Letalys)