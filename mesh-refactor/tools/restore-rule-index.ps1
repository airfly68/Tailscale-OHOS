param([string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path)

$ErrorActionPreference = 'Stop'
$rulesDir = Join-Path $Root 'rules'
$matrixPath = Join-Path $Root 'APPLICABILITY_MATRIX.md'
$indexPath = Join-Path $Root 'RULE_INDEX.md'

function Get-Properties([string]$block) {
  return @([regex]::Matches($block, '(?m)^- \*\*[^*]+\*\*.\s*(.+)$') | ForEach-Object { $_.Groups[1].Value.Trim() })
}

$matrix = Get-Content -Raw -Encoding utf8 $matrixPath
$records = @()
foreach ($rulePath in Get-ChildItem $rulesDir -Filter 'B*.md' | Sort-Object Name) {
  $text = Get-Content -Raw -Encoding utf8 $rulePath.FullName
  $sources = @{}
  foreach ($source in [regex]::Matches($text, '(?m)^-\s+\*\*(S\d+)\*\*.`([^`]+)`')) {
    $sources[$source.Groups[1].Value] = $source.Groups[2].Value
  }
  $sections = [regex]::Matches($text, '(?ms)^### (B\d\d-R\d\d\d)\s*$(.*?)(?=^### B\d\d-R\d\d\d\s*$|\z)')
  foreach ($section in $sections) {
    $id = $section.Groups[1].Value
    $properties = Get-Properties $section.Groups[2].Value
    if ($properties.Count -lt 6) { throw "Incomplete rule record: $id" }
    $row = [regex]::Match($matrix, "(?m)^\| $([regex]::Escape($id)) \|.+$")
    if (-not $row.Success) { throw "Missing matrix row: $id" }
    [string[]]$cells = $row.Value.Trim().Trim('|').Split('|')
    for ($cellIndex = 0; $cellIndex -lt $cells.Length; $cellIndex++) { $cells[$cellIndex] = $cells[$cellIndex].Trim() }
    if ($cells.Length -lt 5) { throw "Malformed matrix row: $id" }
    $sourceNames = (([regex]::Matches($properties[2], 'S\d+') | ForEach-Object { $sources[$_.Value] }) -join '<br>')
    if ([string]::IsNullOrWhiteSpace($sourceNames)) { throw "Missing extracted source path: $id" }
    $records += [pscustomobject]@{
      Id=$id; Level=$properties[1]; Source=$sourceNames; Applies=$properties[5];
      Evidence=("applicability=$($cells[2]); current=$($cells[3]); conclusion=$($cells[4])");
      Conflict=$properties[$properties.Count - 1]
    }
  }
}
if ($records.Count -ne 105) { throw "Expected 105 rules, got $($records.Count)." }

$out = @(
  '# Rule Index',
  '',
  'Restored only from `extracted/` and `rules/`; no source HTML was read. Each record includes',
  'source, level, applicability, matrix evidence, and conflict state. RECOMMENDED, OPTIONAL, and',
  'EXAMPLE entries are planning inputs, not mandatory implementation tasks.',
  '',
  '- Restoration command: mesh-refactor/tools/restore-rule-index.ps1',
  ('- Rule count: {0} (B01=12, B02=22, B03=26, B04=22, B05=23)' -f $records.Count),
  '- Conflict resolution: see `RULE_CONFLICTS.md`.',
  '',
  '| Rule | Level | Extracted source | Applicability | Matrix evidence | Conflict state |',
  '| --- | --- | --- | --- | --- | --- |'
)
foreach ($record in $records) { $out += "| $($record.Id) | $($record.Level) | $($record.Source) | $($record.Applies) | $($record.Evidence) | $($record.Conflict) |" }
Set-Content -Encoding utf8 -Path $indexPath -Value $out
Write-Host "Restored $($records.Count) rule records to $indexPath"
