#Requires -Modules Az.Accounts, Az.Resources

<#
.SYNOPSIS
    Validates Bicep templates and runs what-if analysis.

.DESCRIPTION
    Validates the Bicep infrastructure templates for syntax errors and performs
    a what-if deployment analysis to preview changes before actual deployment.

.PARAMETER Environment
    Target environment (dev or prod). Defaults to 'dev'.

.PARAMETER ResourceGroupName
    Name of the Azure resource group to validate against.

.PARAMETER Location
    Azure region for the resource group. Defaults to 'eastus2'.

.PARAMETER WhatIf
    If set, runs a what-if analysis showing expected changes.

.EXAMPLE
    .\validate.ps1 -Environment dev -ResourceGroupName rg-azure-chatbot-dev
    .\validate.ps1 -Environment prod -ResourceGroupName rg-azure-chatbot-prod -WhatIf
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('dev', 'prod')]
    [string]$Environment = 'dev',

    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter()]
    [string]$Location = 'eastus2',

    [Parameter()]
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'

# Add Azure CLI Bicep to PATH for this session
$bicepPath = "$env:USERPROFILE\.azure\bin"
if (Test-Path $bicepPath) {
    $env:PATH = "$bicepPath;$env:PATH"
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$InfraDir = Join-Path $ScriptDir '..\infrastructure'
$TemplateFile = Join-Path $InfraDir 'main.bicep'
$ParametersFile = Join-Path $InfraDir "parameters.$Environment.json"

function Write-Step {
    param([string]$Message)
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  $Message" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
}

# --- Verify Azure Login ---
Write-Step "Checking Azure Login"

try {
    $context = Get-AzContext
    if (-not $context) { throw "Not logged in" }
    Write-Host "Logged in as: $($context.Account.Id)" -ForegroundColor Green
}
catch {
    Write-Host "Not logged in. Running Connect-AzAccount..." -ForegroundColor Yellow
    Connect-AzAccount
}

# --- Validate Files Exist ---
Write-Step "Validating File Paths"

if (-not (Test-Path $TemplateFile)) {
    throw "Template file not found: $TemplateFile"
}
Write-Host "Template file: $TemplateFile" -ForegroundColor Green

if (-not (Test-Path $ParametersFile)) {
    throw "Parameters file not found: $ParametersFile"
}
Write-Host "Parameters file: $ParametersFile" -ForegroundColor Green

# --- Bicep Build (Syntax Check) ---
Write-Step "Building Bicep Template (Syntax Validation)"

Write-Host "Validating Bicep template via Azure CLI..." -ForegroundColor Yellow
az bicep build --file $TemplateFile 2>&1
if ($LASTEXITCODE -ne 0) {
    throw "Bicep build failed. Ensure Azure CLI is installed with Bicep support."
}

Write-Host "Bicep template syntax is valid." -ForegroundColor Green

# --- Check Parameters for Placeholders ---
Write-Step "Checking Parameters for Placeholder Values"

$paramsContent = Get-Content $ParametersFile -Raw
$placeholders = [regex]::Matches($paramsContent, '<YOUR_[A-Z_]+>')

if ($placeholders.Count -gt 0) {
    Write-Host "WARNING: The following placeholder values were found:" -ForegroundColor Red
    foreach ($match in $placeholders) {
        Write-Host "  - $($match.Value)" -ForegroundColor Red
    }
    Write-Host "`nUpdate these values before deploying." -ForegroundColor Red

    if ($WhatIf) {
        Write-Host "`nSkipping what-if analysis due to placeholder values." -ForegroundColor Yellow
        return
    }
}
else {
    Write-Host "No placeholder values found. Parameters are configured." -ForegroundColor Green
}

# --- ARM Template Validation ---
Write-Step "Validating ARM Deployment"

# Ensure resource group exists for validation
$rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
if (-not $rg) {
    Write-Host "Resource group '$ResourceGroupName' does not exist." -ForegroundColor Yellow
    Write-Host "Creating resource group for validation..." -ForegroundColor Yellow
    New-AzResourceGroup -Name $ResourceGroupName -Location $Location | Out-Null
}

$validationResult = Test-AzResourceGroupDeployment `
    -ResourceGroupName $ResourceGroupName `
    -TemplateFile $TemplateFile `
    -TemplateParameterFile $ParametersFile

if ($validationResult) {
    Write-Host "Validation FAILED:" -ForegroundColor Red
    $validationResult | ForEach-Object {
        Write-Host "  Code: $($_.Code)" -ForegroundColor Red
        Write-Host "  Message: $($_.Message)" -ForegroundColor Red
        Write-Host "  Target: $($_.Target)" -ForegroundColor Red
        Write-Host ""
    }
    throw "Template validation failed."
}
else {
    Write-Host "Template validation passed." -ForegroundColor Green
}

# --- What-If Analysis ---
if ($WhatIf) {
    Write-Step "Running What-If Analysis"

    $whatIfResult = New-AzResourceGroupDeployment `
        -ResourceGroupName $ResourceGroupName `
        -TemplateFile $TemplateFile `
        -TemplateParameterFile $ParametersFile `
        -WhatIf `
        -WhatIfResultFormat FullResourcePayloads

    Write-Host "`nWhat-If analysis complete." -ForegroundColor Green
}

Write-Step "Validation Complete"
Write-Host "All checks passed for environment: $Environment" -ForegroundColor Green
