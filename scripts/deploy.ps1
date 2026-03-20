#Requires -Modules Az.Accounts, Az.Resources

<#
.SYNOPSIS
    Deploys Azure AI Chatbot infrastructure and application code.

.DESCRIPTION
    Main deployment orchestration script. Deploys Bicep infrastructure templates
    and optionally deploys application code to the provisioned resources.

.PARAMETER Environment
    Target environment (dev or prod). Defaults to 'dev'.

.PARAMETER ResourceGroupName
    Name of the Azure resource group to deploy to.

.PARAMETER Location
    Azure region for the resource group. Defaults to 'eastus2'.

.PARAMETER InfraOnly
    If set, only deploys infrastructure (skips application code deployment).

.PARAMETER AppOnly
    If set, only deploys application code (skips infrastructure).

.EXAMPLE
    .\deploy.ps1 -Environment dev -ResourceGroupName rg-azure-chatbot-dev -Location eastus2
    .\deploy.ps1 -Environment prod -ResourceGroupName rg-azure-chatbot-prod -InfraOnly
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
    [switch]$InfraOnly,

    [Parameter()]
    [switch]$AppOnly
)

$ErrorActionPreference = 'Stop'

# Add Azure CLI Bicep to PATH for this session
$bicepPath = "$env:USERPROFILE\.azure\bin"
if (Test-Path $bicepPath) {
    $env:PATH = "$bicepPath;$env:PATH"
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$InfraDir = Join-Path $ScriptDir '..\infrastructure'
$BackendDir = Join-Path $ScriptDir '..\backend'
$FrontendDir = Join-Path $ScriptDir '..\frontend'
$TemplateFile = Join-Path $InfraDir 'main.bicep'
$ParametersFile = Join-Path $InfraDir "parameters.$Environment.json"

# --- Helper Functions ---
function Write-Step {
    param([string]$Message)
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  $Message" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
}

function Test-AzureLogin {
    try {
        $context = Get-AzContext
        if (-not $context) {
            throw "Not logged in"
        }
        Write-Host "Logged in as: $($context.Account.Id)" -ForegroundColor Green
        Write-Host "Subscription: $($context.Subscription.Name) ($($context.Subscription.Id))" -ForegroundColor Green
    }
    catch {
        Write-Host "Not logged into Azure. Running Connect-AzAccount..." -ForegroundColor Yellow
        Connect-AzAccount
    }
}

function Purge-SoftDeletedCognitiveServicesAccount {
    param(
        [string]$AccountName
    )

    Write-Host "Checking for soft-deleted Cognitive Services account '$AccountName'..." -ForegroundColor Yellow

    $subscriptionId = (Get-AzContext).Subscription.Id
    $listPath = "/subscriptions/$subscriptionId/providers/Microsoft.CognitiveServices/deletedAccounts?api-version=2024-10-01"

    try {
        $response = Invoke-AzRestMethod -Path $listPath -Method GET
        if ($response.StatusCode -eq 200) {
            $deletedAccounts = ($response.Content | ConvertFrom-Json).value
            $matchingAccount = $deletedAccounts | Where-Object {
                $_.id -like "*/deletedAccounts/$AccountName"
            }

            if ($matchingAccount) {
                Write-Host "Found soft-deleted account '$AccountName'. Purging..." -ForegroundColor Yellow
                $purgePath = "$($matchingAccount.id)?api-version=2024-10-01"
                $purgeResponse = Invoke-AzRestMethod -Path $purgePath -Method DELETE

                if ($purgeResponse.StatusCode -in @(200, 202, 204)) {
                    Write-Host "Soft-deleted account purged successfully. Waiting for propagation..." -ForegroundColor Green
                    Start-Sleep -Seconds 15
                }
                else {
                    Write-Host "WARNING: Failed to purge soft-deleted account. Status: $($purgeResponse.StatusCode)" -ForegroundColor Yellow
                    Write-Host $purgeResponse.Content -ForegroundColor Yellow
                }
            }
            else {
                Write-Host "No soft-deleted account found with name '$AccountName'." -ForegroundColor Green
            }
        }
    }
    catch {
        Write-Host "WARNING: Could not check for soft-deleted Cognitive Services accounts: $_" -ForegroundColor Yellow
    }
}

function Ensure-ResourceGroup {
    param(
        [string]$Name,
        [string]$Loc
    )
    $rg = Get-AzResourceGroup -Name $Name -ErrorAction SilentlyContinue
    if (-not $rg) {
        Write-Host "Creating resource group '$Name' in '$Loc'..." -ForegroundColor Yellow
        New-AzResourceGroup -Name $Name -Location $Loc | Out-Null
        Write-Host "Resource group created." -ForegroundColor Green
    }
    else {
        Write-Host "Resource group '$Name' already exists." -ForegroundColor Green
    }
}

# --- Validation ---
Write-Step "Validating Prerequisites"

Test-AzureLogin

if (-not (Test-Path $TemplateFile)) {
    throw "Bicep template not found: $TemplateFile"
}

if (-not (Test-Path $ParametersFile)) {
    throw "Parameters file not found: $ParametersFile"
}

# Check for placeholder values in parameters file
$paramsContent = Get-Content $ParametersFile -Raw
if ($paramsContent -match '<YOUR_') {
    Write-Host "WARNING: Parameters file contains placeholder values (<YOUR_...>)." -ForegroundColor Red
    Write-Host "Please update '$ParametersFile' with your actual Azure configuration before deploying." -ForegroundColor Red
    throw "Parameters file contains placeholder values. Update before deploying."
}

Write-Host "Environment: $Environment" -ForegroundColor White
Write-Host "Resource Group: $ResourceGroupName" -ForegroundColor White
Write-Host "Location: $Location" -ForegroundColor White
Write-Host "Template: $TemplateFile" -ForegroundColor White
Write-Host "Parameters: $ParametersFile" -ForegroundColor White

# --- Infrastructure Deployment ---
if (-not $AppOnly) {
    Write-Step "Deploying Infrastructure ($Environment)"

    Ensure-ResourceGroup -Name $ResourceGroupName -Loc $Location

    # Purge soft-deleted Cognitive Services account if it exists (prevents name conflict)
    $paramsJson = Get-Content $ParametersFile -Raw | ConvertFrom-Json
    $cognitiveAccountName = "$($paramsJson.parameters.appName.value)-ai-$Environment"
    Purge-SoftDeletedCognitiveServicesAccount -AccountName $cognitiveAccountName

    $deploymentName = "azure-chatbot-$Environment-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

    Write-Host "Starting deployment '$deploymentName'..." -ForegroundColor Yellow

    $deployment = New-AzResourceGroupDeployment `
        -Name $deploymentName `
        -ResourceGroupName $ResourceGroupName `
        -TemplateFile $TemplateFile `
        -TemplateParameterFile $ParametersFile `
        -Verbose

    if ($deployment.ProvisioningState -eq 'Succeeded') {
        Write-Host "`nInfrastructure deployment succeeded!" -ForegroundColor Green
        Write-Host "`nDeployment Outputs:" -ForegroundColor Cyan
        Write-Host "  Frontend URL:          $($deployment.Outputs.frontendUrl.Value)" -ForegroundColor White
        Write-Host "  Backend URL:           $($deployment.Outputs.backendUrl.Value)" -ForegroundColor White
        Write-Host "  AI Foundry Endpoint:   $($deployment.Outputs.aiFoundryEndpoint.Value)" -ForegroundColor White
        Write-Host "  Managed Identity ID:   $($deployment.Outputs.managedIdentityClientId.Value)" -ForegroundColor White
        Write-Host "  Static Web App Name:   $($deployment.Outputs.staticWebAppName.Value)" -ForegroundColor White
        Write-Host "  Container App Name:    $($deployment.Outputs.containerAppName.Value)" -ForegroundColor White
        Write-Host "  ACR Name:              $($deployment.Outputs.acrName.Value)" -ForegroundColor White
    }
    else {
        throw "Infrastructure deployment failed with state: $($deployment.ProvisioningState)"
    }
}

# --- Application Code Deployment ---
if (-not $InfraOnly) {
    Write-Step "Deploying Application Code ($Environment)"

    # Get resource names from existing deployment or from the last infra deployment
    if ($AppOnly) {
        $lastDeployment = Get-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName |
            Where-Object { $_.DeploymentName -like "azure-chatbot-$Environment-*" } |
            Sort-Object Timestamp -Descending |
            Select-Object -First 1

        if (-not $lastDeployment) {
            throw "No previous infrastructure deployment found. Run without -AppOnly first."
        }

        $containerAppName = $lastDeployment.Outputs.containerAppName.Value
        $acrName = $lastDeployment.Outputs.acrName.Value
        $staticWebAppName = $lastDeployment.Outputs.staticWebAppName.Value
        $backendUrl = $lastDeployment.Outputs.backendUrl.Value
    }
    else {
        $containerAppName = $deployment.Outputs.containerAppName.Value
        $acrName = $deployment.Outputs.acrName.Value
        $staticWebAppName = $deployment.Outputs.staticWebAppName.Value
        $backendUrl = $deployment.Outputs.backendUrl.Value
    }

    # Deploy Backend to Container App via ACR
    Write-Host "`nDeploying backend to Container App '$containerAppName'..." -ForegroundColor Yellow

    $acrLoginServer = "$acrName.azurecr.io"
    $imageTag = "$acrLoginServer/backend:$(Get-Date -Format 'yyyyMMdd-HHmmss')"

    Push-Location $BackendDir
    try {
        # Build image locally
        $imageTag = "$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        $localImage = "backend:$imageTag"
        $fullImage = "$acrLoginServer/$localImage"

        Write-Host "Building Docker image locally '$localImage'..." -ForegroundColor Yellow
        docker build -t $localImage -t $fullImage -f Dockerfile . 2>&1 | ForEach-Object { Write-Host $_ }
        if ($LASTEXITCODE -ne 0) { throw "Docker build failed." }

        # Login to ACR
        Write-Host "Logging in to ACR '$acrName'..." -ForegroundColor Yellow
        az acr login --name $acrName 2>&1 | ForEach-Object { Write-Host $_ }
        if ($LASTEXITCODE -ne 0) { throw "ACR login failed." }

        # Push image to ACR
        Write-Host "Pushing image to ACR '$fullImage'..." -ForegroundColor Yellow
        docker push $fullImage 2>&1 | ForEach-Object { Write-Host $_ }
        if ($LASTEXITCODE -ne 0) { throw "Docker push failed." }

        # Update Container App with the new image
        Write-Host "Updating Container App with image '$fullImage'..." -ForegroundColor Yellow
        az containerapp update --name $containerAppName --resource-group $ResourceGroupName --image $fullImage 2>&1 | ForEach-Object { Write-Host $_ }
        if ($LASTEXITCODE -ne 0) { throw "Container App update failed." }

        Write-Host "Backend deployment complete." -ForegroundColor Green
    }
    finally {
        Pop-Location
    }

    # Deploy Frontend to Static Web App
    Write-Host "`nDeploying frontend to Static Web App '$staticWebAppName'..." -ForegroundColor Yellow

    Push-Location $FrontendDir
    try {
        # Build frontend with production API URL
        $env:REACT_APP_API_BASE_URL = $backendUrl
        Write-Host "Building frontend with API URL: $backendUrl" -ForegroundColor Yellow
        npm run build

        if (-not (Test-Path 'build')) {
            throw "Frontend build failed - 'build' directory not found."
        }

        # Deploy using Azure Static Web Apps CLI (swa)
        $swaInstalled = Get-Command swa -ErrorAction SilentlyContinue
        if (-not $swaInstalled) {
            Write-Host "Installing Azure Static Web Apps CLI..." -ForegroundColor Yellow
            npm install -g @azure/static-web-apps-cli
        }

        $deploymentToken = (Get-AzStaticWebAppSecret -ResourceGroupName $ResourceGroupName -Name $staticWebAppName).Properties.ApiKey
        swa deploy ./build --deployment-token $deploymentToken --env $Environment

        Write-Host "Frontend deployment complete." -ForegroundColor Green
    }
    finally {
        Pop-Location
    }
}

# --- Summary ---
Write-Step "Deployment Complete"

Write-Host "Environment:  $Environment" -ForegroundColor Green
if (-not $AppOnly) {
    Write-Host "Frontend URL: $($deployment.Outputs.frontendUrl.Value)" -ForegroundColor Green
    Write-Host "Backend URL:  $($deployment.Outputs.backendUrl.Value)" -ForegroundColor Green
}
Write-Host "`nDone!" -ForegroundColor Green
