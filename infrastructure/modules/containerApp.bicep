// Azure Container Apps module for backend API hosting
// Replaces App Service to avoid App Service Plan VM quota restrictions

@description('Application name prefix')
param appName string

@description('Environment name (dev, prod)')
param environment string

@description('Location for resources')
param location string

@description('Managed Identity resource ID')
param managedIdentityId string

@description('Managed Identity client ID')
param managedIdentityClientId string

@description('Frontend origin for CORS')
param frontendOrigin string

@description('Azure AI Foundry endpoint')
param aiFoundryEndpoint string

@description('Azure AI Foundry model deployment name')
param aiFoundryDeployment string = 'gpt-4o'

@description('Azure AI Foundry API version')
param aiFoundryApiVersion string = '2024-04-01-preview'

@description('Entra ID tenant ID')
param tenantId string

@description('Backend API app registration client ID')
param backendClientId string

@description('SPA app registration client ID')
param spaClientId string

@description('Application Insights connection string (optional)')
param appInsightsConnectionString string = ''

@description('Container CPU cores')
param containerCpu string = '0.5'

@description('Container memory')
param containerMemory string = '1Gi'

var containerAppEnvName = '${appName}-env-${environment}'
var containerAppName = '${appName}-api-${environment}'
var logAnalyticsName = '${appName}-logs-${environment}'
var acrName = replace('${appName}acr${environment}', '-', '')

// --- Log Analytics Workspace (required by Container Apps Environment) ---
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
  tags: {
    environment: environment
    application: appName
    component: 'monitoring'
  }
}

// --- Azure Container Registry ---
resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: acrName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true
  }
  tags: {
    environment: environment
    application: appName
    component: 'registry'
  }
}

// --- Container Apps Environment ---
resource containerAppEnv 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: containerAppEnvName
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
  }
  tags: {
    environment: environment
    application: appName
    component: 'backend'
  }
}

// --- Container App ---
resource containerApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: containerAppName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityId}': {}
    }
  }
  properties: {
    managedEnvironmentId: containerAppEnv.id
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 8080
        transport: 'http'
        allowInsecure: false
        corsPolicy: {
          allowedOrigins: [
            frontendOrigin
          ]
          allowCredentials: false
          allowedMethods: [
            'GET'
            'POST'
            'PUT'
            'DELETE'
            'OPTIONS'
          ]
          allowedHeaders: [
            '*'
          ]
        }
      }
      registries: [
        {
          server: acr.properties.loginServer
          username: acr.listCredentials().username
          passwordSecretRef: 'acr-password'
        }
      ]
      secrets: [
        {
          name: 'acr-password'
          value: acr.listCredentials().passwords[0].value
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'backend'
          // Placeholder image; replaced during code deployment
          image: 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
          resources: {
            cpu: json(containerCpu)
            memory: containerMemory
          }
          env: [
            {
              name: 'AZURE_TENANT_ID'
              value: tenantId
            }
            {
              name: 'AZURE_CLIENT_ID'
              value: backendClientId
            }
            {
              name: 'AZURE_CLIENT_ID_SPA'
              value: spaClientId
            }
            {
              name: 'AZURE_AI_FOUNDRY_ENDPOINT'
              value: aiFoundryEndpoint
            }
            {
              name: 'AZURE_AI_FOUNDRY_DEPLOYMENT'
              value: aiFoundryDeployment
            }
            {
              name: 'AZURE_AI_FOUNDRY_MODEL'
              value: aiFoundryDeployment
            }
            {
              name: 'AZURE_AI_FOUNDRY_API_VERSION'
              value: aiFoundryApiVersion
            }
            {
              name: 'AZURE_CLIENT_ID_MANAGED_IDENTITY'
              value: managedIdentityClientId
            }
            {
              name: 'FRONTEND_ORIGIN'
              value: frontendOrigin
            }
            {
              name: 'PORT'
              value: '8080'
            }
            {
              name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
              value: appInsightsConnectionString
            }
          ]
        }
      ]
      scale: {
        minReplicas: 0
        maxReplicas: 3
        rules: [
          {
            name: 'http-rule'
            http: {
              metadata: {
                concurrentRequests: '100'
              }
            }
          }
        ]
      }
    }
  }
  tags: {
    environment: environment
    application: appName
    component: 'backend'
  }
}

@description('Container App FQDN')
output fqdn string = containerApp.properties.configuration.ingress.fqdn

@description('Container App URL')
output url string = 'https://${containerApp.properties.configuration.ingress.fqdn}'

@description('Container App resource ID')
output id string = containerApp.id

@description('Container App name')
output name string = containerApp.name

@description('Container Apps Environment name')
output envName string = containerAppEnv.name

@description('ACR login server')
output acrLoginServer string = acr.properties.loginServer

@description('ACR name')
output acrName string = acr.name
