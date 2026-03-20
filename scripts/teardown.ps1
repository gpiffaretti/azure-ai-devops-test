#Requires -Modules Az.Accounts, Az.Resources

<#
.SYNOPSIS
    Tears down Azure AI Chatbot infrastructure resources.

.DESCRIPTION
    Removes the resource group and all contained resources for a given environment.
    Includes a confirmation prompt to prevent accidental deletions.

.PARAMETER Environment
    Target environment (dev or prod). Defaults to 'dev'.

.PARAMETER ResourceGroupName
    Name of the Azure resource group to delete.

.PARAMETER Force
    If set, skips the confirmation prompt.

.EXAMPLE
    .\teardown.ps1 -Environment dev -ResourceGroupName rg-azure-chatbot-dev
    .\teardown.ps1 -Environment prod -ResourceGroupName rg-azure-chatbot-prod -Force
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('dev', 'prod')]
    [string]$Environment = 'dev',

    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter()]
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

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
    Write-Host "Subscription: $($context.Subscription.Name)" -ForegroundColor Green
}
catch {
    Write-Host "Not logged in. Running Connect-AzAccount..." -ForegroundColor Yellow
    Connect-AzAccount
}

# --- Check Resource Group Exists ---
Write-Step "Checking Resource Group"

$rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue

if (-not $rg) {
    Write-Host "Resource group '$ResourceGroupName' does not exist. Nothing to tear down." -ForegroundColor Yellow
    return
}

# List resources in the group
$resources = Get-AzResource -ResourceGroupName $ResourceGroupName

Write-Host "Resource group: $ResourceGroupName" -ForegroundColor White
Write-Host "Location: $($rg.Location)" -ForegroundColor White
Write-Host "Environment: $Environment" -ForegroundColor White
Write-Host "`nResources to be deleted ($($resources.Count)):" -ForegroundColor Yellow

foreach ($resource in $resources) {
    Write-Host "  - [$($resource.ResourceType)] $($resource.Name)" -ForegroundColor White
}

# --- Confirmation ---
if (-not $Force) {
    Write-Host "`n" -NoNewline
    Write-Host "WARNING: This will permanently delete the resource group '$ResourceGroupName'" -ForegroundColor Red
    Write-Host "and ALL $($resources.Count) resource(s) within it. This action CANNOT be undone." -ForegroundColor Red
    Write-Host ""

    $confirmation = Read-Host "Type the resource group name to confirm deletion"

    if ($confirmation -ne $ResourceGroupName) {
        Write-Host "`nConfirmation did not match. Teardown cancelled." -ForegroundColor Yellow
        return
    }
}

# --- Delete Resource Group ---
Write-Step "Deleting Resource Group"

Write-Host "Deleting resource group '$ResourceGroupName'..." -ForegroundColor Yellow
Write-Host "This may take several minutes..." -ForegroundColor Yellow

Remove-AzResourceGroup -Name $ResourceGroupName -Force

Write-Host "`nResource group '$ResourceGroupName' has been deleted." -ForegroundColor Green

Write-Step "Teardown Complete"
Write-Host "Environment '$Environment' resources have been removed." -ForegroundColor Green
Write-Host "`nReminder: Entra ID App Registrations are NOT deleted by this script." -ForegroundColor Yellow
Write-Host "To fully clean up, manually delete app registrations in the Azure Portal:" -ForegroundColor Yellow
Write-Host "  - azure-chatbot-api" -ForegroundColor White
Write-Host "  - azure-chatbot-spa" -ForegroundColor White
