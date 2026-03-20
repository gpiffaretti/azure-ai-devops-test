// Static Web App module for frontend SPA hosting

@description('Application name prefix')
param appName string

@description('Environment name (dev, prod)')
param environment string

@description('Location for the Static Web App')
param location string

@description('SKU for the Static Web App')
@allowed(['Free', 'Standard'])
param sku string = 'Free'

@description('Custom domain (optional)')
param customDomain string = ''

var staticWebAppName = '${appName}-swa-${environment}'

resource staticWebApp 'Microsoft.Web/staticSites@2024-04-01' = {
  name: staticWebAppName
  location: location
  sku: {
    name: sku
    tier: sku
  }
  properties: {
    stagingEnvironmentPolicy: 'Enabled'
    allowConfigFileUpdates: true
    buildProperties: {
      appLocation: '/frontend'
      outputLocation: 'build'
      appBuildCommand: 'npm run build'
    }
  }
  tags: {
    environment: environment
    application: appName
    component: 'frontend'
  }
}

resource customDomainResource 'Microsoft.Web/staticSites/customDomains@2024-04-01' = if (!empty(customDomain)) {
  parent: staticWebApp
  name: customDomain
  properties: {}
}

@description('Static Web App default hostname')
output defaultHostname string = staticWebApp.properties.defaultHostname

@description('Static Web App resource ID')
output id string = staticWebApp.id

@description('Static Web App name')
output name string = staticWebApp.name

@description('Static Web App API key for deployment')
output apiKey string = staticWebApp.listSecrets().properties.apiKey
