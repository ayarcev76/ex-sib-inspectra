# commit_progress.ps1
# Коммит текущего прогресса разработки (29.07.2026)
# Запуск: powershell -ExecutionPolicy Bypass -File .\commit_progress.ps1

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  COMMIT PROGRESS (29.07.2026)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Проверяем, что мы в git-репозитории
if (-not (Test-Path ".git")) {
    Write-Host "[ERROR] Not a git repository" -ForegroundColor Red
    Write-Host "Please run this script from the root of ex-sib-inspectra/" -ForegroundColor Yellow
    exit 1
}

# Показываем текущий статус
Write-Host "[1/4] Checking git status..." -ForegroundColor Cyan
git status --short
Write-Host ""

# Проверяем, есть ли изменения для коммита
$changes = git status --porcelain
if ([string]::IsNullOrWhiteSpace($changes)) {
    Write-Host "[WARN] No changes to commit" -ForegroundColor Yellow
    exit 0
}

# Добавляем все изменения
Write-Host "[2/4] Staging all changes..." -ForegroundColor Cyan
git add -A
Write-Host "  [OK] All changes staged" -ForegroundColor Green
Write-Host ""

# Создаём коммит
Write-Host "[3/4] Creating commit..." -ForegroundColor Cyan

$commitMessage = @"
feat: progress 29.07.2026 - UI improvements and server filtering

Backend:
- Fixed 405 Method Not Allowed on reference deletion
- Added DELETE endpoints for all references (PE, Department, Contractor, WorkType, ZPBRule)
- Added IntegrityError handling for ON DELETE RESTRICT protection
- Implemented server-side filtering and pagination for inspections list
- Added filter params: pe_id, department_id, date_from, date_to, status
- Added CurrentUser authorization to inspection endpoints

Frontend:
- Updated Layout.tsx: EUROCHEM corporate branding (green #00A651)
- Added collapsible sidebar with MenuFoldOutlined button
- Added breadcrumbs with automatic URL generation
- Added notification bell (stub for Stage 3)
- Improved profile dropdown: Russian role names (Administrator, Inspector, etc.)
- Grouped admin menu items under "Administration" submenu
- Renamed "Inspections" to "Observation Cards" (per TZ p.5)
- Reworked References.tsx: departments linked to PE via expandable rows
- Added server-side filtering in Inspections.tsx (PE, department, date range, status)
- Reworked InspectionDetail.tsx:
  * "All Safe" banner (when no violations)
  * Statistics cards "Violations found" and "TOP violations"
  * "WORKS STOPPED" banner
  * "ZPB RULES VIOLATED" banner with rules list

Known issues:
- PDF export with Cyrillic deferred due to xhtml2pdf bug on Windows (PermissionError when copying font to temp folder with 8.3 short name)
- DOCX export works correctly
"@

git commit -m $commitMessage

if ($LASTEXITCODE -eq 0) {
    Write-Host "  [OK] Commit created successfully" -ForegroundColor Green
} else {
    Write-Host "  [ERROR] Failed to create commit" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Показываем лог
Write-Host "[4/4] Recent commits:" -ForegroundColor Cyan
git log --oneline -5
Write-Host ""

Write-Host "========================================" -ForegroundColor Green
Write-Host "  COMMIT COMPLETED SUCCESSFULLY!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  * git push origin develop   # push to remote" -ForegroundColor White
Write-Host "  * Create Pull Request to main" -ForegroundColor White
Write-Host ""