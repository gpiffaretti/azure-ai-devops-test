// Managed Identity and RBAC role assignments module

@description('Application name prefix')
param appName string

@description('Environment name (dev, prod)')
param environment string

@description('Location for the managed identity')
param location string

@description('AI Foundry (Cognitive Services) resource ID for RBAC assignment')
param aiFoundryResourceId string

var identityName = '${appName}-identity-${environment}'

// Cognitive Services OpenAI User role definition ID
var cognitiveServicesOpenAIUserRoleId = '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: identityName
  location: location
  tags: {
    environment: environment
    application: appName
    component: 'identity'
  }
}

// Assign "Cognitive Services OpenAI User" role to the managed identity on the AI Foundry resource
resource cognitiveServicesRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aiFoundryResourceId, managedIdentity.id, cognitiveServicesOpenAIUserRoleId)
  scope: aiFoundryResource
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', cognitiveServicesOpenAIUserRoleId)
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// Reference to the existing AI Foundry resource for scoping
resource aiFoundryResource 'Microsoft.CognitiveServices/accounts@2024-10-01' existing = {
  name: last(split(aiFoundryResourceId, '/'))
}

@description('Managed Identity resource ID')
output id string = managedIdentity.id

@description('Managed Identity principal ID')
output principalId string = managedIdentity.properties.principalId

@description('Managed Identity client ID')
output clientId string = managedIdentity.properties.clientId

@description('Managed Identity name')
output name string = managedIdentity.name
