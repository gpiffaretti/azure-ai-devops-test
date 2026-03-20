// Main orchestration template for Azure AI Chatbot infrastructure
// Deploys: Static Web App, Container Apps, AI Foundry, Managed Identity + RBAC

targetScope = 'resourceGroup'

@description('Application name prefix used for all resources')
param appName string

@description('Environment name (dev, prod, or dynamic PR environment name)')
param environment string

@description('Primary Azure region for resources')
param location string = resourceGroup().location

@description('Static Web App SKU')
@allowed(['Free', 'Standard'])
param staticWebAppSku string = 'Free'

@description('AI Foundry model deployment name')
param aiModelDeploymentName string = 'gpt-4o'

@description('AI Foundry model name')
param aiModelName string = 'gpt-4o'

@description('AI Foundry model version')
param aiModelVersion string = '2024-08-06'

@description('AI Foundry model capacity (TPM in thousands)')
param aiModelCapacity int = 30

@description('Enable public network access on AI Foundry')
param aiPublicNetworkAccess bool = true

@description('Entra ID tenant ID')
param tenantId string

@description('Backend API app registration client ID')
param backendClientId string

@description('SPA app registration client ID')
param spaClientId string

@description('Custom domain for Static Web App (optional)')
param customDomain string = ''

@description('Application Insights connection string (optional, Phase 6)')
param appInsightsConnectionString string = ''

// --- Module: AI Foundry ---
module aiFoundry 'modules/aiFoundry.bicep' = {
  name: 'deploy-ai-foundry'
  params: {
    appName: appName
    environment: environment
    location: location
    modelDeploymentName: aiModelDeploymentName
    modelName: aiModelName
    modelVersion: aiModelVersion
    modelCapacity: aiModelCapacity
    publicNetworkAccess: aiPublicNetworkAccess
  }
}

// --- Module: Managed Identity + RBAC ---
module managedIdentity 'modules/managedIdentity.bicep' = {
  name: 'deploy-managed-identity'
  params: {
    appName: appName
    environment: environment
    location: location
    aiFoundryResourceId: aiFoundry.outputs.id
  }
}

// --- Module: Static Web App (Frontend) ---
module staticWebApp 'modules/staticWebApp.bicep' = {
  name: 'deploy-static-web-app'
  params: {
    appName: appName
    environment: environment
    location: location
    sku: staticWebAppSku
    customDomain: customDomain
  }
}

// --- Module: Container Apps (Backend) ---
module containerApp 'modules/containerApp.bicep' = {
  name: 'deploy-container-app'
  params: {
    appName: appName
    environment: environment
    location: location
    managedIdentityId: managedIdentity.outputs.id
    managedIdentityClientId: managedIdentity.outputs.clientId
    frontendOrigin: 'https://${staticWebApp.outputs.defaultHostname}'
    aiFoundryEndpoint: aiFoundry.outputs.endpoint
    aiFoundryDeployment: aiModelDeploymentName
    tenantId: tenantId
    backendClientId: backendClientId
    spaClientId: spaClientId
    appInsightsConnectionString: appInsightsConnectionString
  }
}

// --- Outputs ---
@description('Static Web App URL')
output frontendUrl string = 'https://${staticWebApp.outputs.defaultHostname}'

@description('Backend API URL')
output backendUrl string = containerApp.outputs.url

@description('AI Foundry endpoint')
output aiFoundryEndpoint string = aiFoundry.outputs.endpoint

@description('Managed Identity client ID')
output managedIdentityClientId string = managedIdentity.outputs.clientId

@description('Static Web App name')
output staticWebAppName string = staticWebApp.outputs.name

@description('Container App name')
output containerAppName string = containerApp.outputs.name

@description('ACR name')
output acrName string = containerApp.outputs.acrName
