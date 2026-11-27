@description('Azure region for the App Service resources.')
param location string = resourceGroup().location

@description('Azure region for the Private Endpoint (must match the VNet/subnet region).')
param privateEndpointLocation string = location

@description('Naming seed for resources (e.g., finance-prod-01).')
param nameSeed string

@description('Name of the App Service Plan.')
param planName string

@description('Name of the Web App Service.')
param webAppName string

@description('Name of the API App Service.')
param apiAppName string

@description('SKU name for App Service Plan.')
param planSkuName string = 'B1'

@description('Number of worker instances.')
param planCapacity int = 1

@description('Linux runtime stack for the Next.js Web App.')
param webAppLinuxFxVersion string = 'NODE|22-lts'

@description('Linux runtime stack for the API App.')
param apiAppLinuxFxVersion string = 'DOTNETCORE|10.0'

@description('Subnet ID for Web App VNet integration.')
param webSubnetId string

@description('Subnet ID for API App VNet integration.')
param apiSubnetId string

@description('Subnet ID for Private Endpoints.')
param peSubnetId string

@description('Resource ID of the existing Private DNS zone.')
param privateDnsZoneId string

@description('FQDN of the backend SQL Server.')
param sqlServerFqdn string

@description('Name of the backend SQL Database.')
param databaseName string

@description('API App Entra ID Client ID.')
param apiAuthAppClientId string

@description('Key Vault Secret Reference for API Auth Client Secret.')
@secure()
param apiAuthAppSecretRef string = ''

@description('Tags applied to app tier resources.')
param tags object = {}

var apiPeName = 'pe-api-${nameSeed}'
var webPeName = 'pe-web-${nameSeed}'

module planModule './appServicePlan.bicep' = {
  name: 'plan-${nameSeed}'
  params: {
    location: location
    planName: planName
    skuName: planSkuName
    capacity: planCapacity
    tags: tags
  }
}

module apiAppModule './appService.bicep' = {
  name: 'api-${nameSeed}'
  params: {
    location: location
    appName: apiAppName
    planId: planModule.outputs.planId
    linuxFxVersion: apiAppLinuxFxVersion
    subnetId: apiSubnetId
    connectionStrings: [
      {
        name: 'SampleApiContext'
        connectionString: 'Server=tcp:${sqlServerFqdn},1433;Initial Catalog=${databaseName};Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;Authentication="Active Directory Default";'
        type: 'SQLAzure'
      }
    ]
    useAuth: true
    authClientId: apiAuthAppClientId
    authClientSecret: apiAuthAppSecretRef
    isApi: true
    tags: tags
  }
}

module webAppModule './appService.bicep' = {
  name: 'web-${nameSeed}'
  params: {
    location: location
    appName: webAppName
    planId: planModule.outputs.planId
    linuxFxVersion: webAppLinuxFxVersion
    subnetId: webSubnetId
    appSettings: [
      {
        name: 'ApiUri'
        value: 'https://${apiAppModule.outputs.appUrl}'
      }
      {
        name: 'ApiAuthUri'
        value: 'api://${apiAuthAppClientId}'
      }
    ]
    useAuth: false
    isApi: false
    tags: tags
  }
}

module apiAppPrivateEndpoint './privateEndpoint.bicep' = {
  name: 'pe-api-${nameSeed}'
  params: {
    location: privateEndpointLocation
    privateEndpointName: apiPeName
    subnetId: peSubnetId
    resourceId: apiAppModule.outputs.appId
    groupId: 'sites'
    dnsZoneId: privateDnsZoneId
    tags: tags
  }
}

module webAppPrivateEndpoint './privateEndpoint.bicep' = {
  name: 'pe-web-${nameSeed}'
  params: {
    location: privateEndpointLocation
    privateEndpointName: webPeName
    subnetId: peSubnetId
    resourceId: webAppModule.outputs.appId
    groupId: 'sites'
    dnsZoneId: privateDnsZoneId
    tags: tags
  }
}

@description('Full HTTPS URL of the Web App.')
output webAppUrl string = 'https://${webAppModule.outputs.appUrl}'

@description('Full HTTPS URL of the API App.')
output apiAppUrl string = 'https://${apiAppModule.outputs.appUrl}'

@description('Resource ID of the App Service Plan.')
output planId string = planModule.outputs.planId

@description('Resource ID of the Web App.')
output webAppId string = webAppModule.outputs.appId

@description('Resource ID of the API App.')
output apiAppId string = apiAppModule.outputs.appId
