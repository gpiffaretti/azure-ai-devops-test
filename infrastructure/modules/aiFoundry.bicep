// Azure AI Foundry (Cognitive Services OpenAI) module

@description('Application name prefix')
param appName string

@description('Environment name (dev, prod)')
param environment string

@description('Location for the AI Foundry resource')
param location string

@description('SKU for the Cognitive Services account')
@allowed(['S0'])
param sku string = 'S0'

@description('Model deployment name')
param modelDeploymentName string = 'gpt-4o'

@description('Model name')
param modelName string = 'gpt-4o'

@description('Model version')
param modelVersion string = '2024-08-06'

@description('Model capacity (TPM in thousands)')
param modelCapacity int = 30

@description('Enable public network access')
param publicNetworkAccess bool = true

var accountName = '${appName}-ai-${environment}'

resource cognitiveServicesAccount 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: accountName
  location: location
  kind: 'OpenAI'
  sku: {
    name: sku
  }
  properties: {
    customSubDomainName: accountName
    publicNetworkAccess: publicNetworkAccess ? 'Enabled' : 'Disabled'
    networkAcls: {
      defaultAction: publicNetworkAccess ? 'Allow' : 'Deny'
    }
  }
  tags: {
    environment: environment
    application: appName
    component: 'ai'
  }
}

resource modelDeployment 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = {
  parent: cognitiveServicesAccount
  name: modelDeploymentName
  sku: {
    name: 'Standard'
    capacity: modelCapacity
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: modelName
      version: modelVersion
    }
  }
}

@description('AI Foundry endpoint URL')
output endpoint string = cognitiveServicesAccount.properties.endpoint

@description('AI Foundry resource ID')
output id string = cognitiveServicesAccount.id

@description('AI Foundry account name')
output name string = cognitiveServicesAccount.name
