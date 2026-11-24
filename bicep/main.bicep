targetScope = 'subscription'

var workload = 'finance'
var environment = 'prod'
var location = 'centralus'
var instanceIndex = 1
var extraTags = {}
var vnetAddressPrefix = '10.1.0.0/16'
var hubSubscriptionId = '7f493ff6-603b-4254-a6bf-e9acfc665866'
var hubResourceGroupName = 'rg-connectivity-hub-prod'
var hubVnetName = 'vnet-platform-connectivity-prod'
var hubVnetId = '/subscriptions/${hubSubscriptionId}/resourceGroups/${hubResourceGroupName}/providers/Microsoft.Network/virtualNetworks/${hubVnetName}'

// padLeft requires a string
var nameSeed = '${workload}-${environment}-${padLeft(string(instanceIndex), 2, '0')}'

var baselineTags = union(extraTags, {
  workload: workload
  environment: environment
  managedBy: 'bicep-deployment-stack'
  costCenter: toLower('${workload}-${environment}')
})

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-${nameSeed}'
  location: location
  tags: baselineTags
}

module network './modules/network.bicep' = {
  name: 'network-${nameSeed}'
  scope: rg
  params: {
    location: location
    nameSeed: nameSeed
    vnetAddressPrefix: vnetAddressPrefix
    hubVnetId: hubVnetId
    hubVnetName: hubVnetName
    tags: baselineTags
  }
}

module sqlDnsZone './modules/privateDns.bicep' = {
  name: 'sqlDnsZone'
  params: {
    dnsZoneName:  'privatelink${environment().suffixes.sqlServerHostname}'
    vnetId: vnetModule.outputs.virtualNetworkId 
  }
}

//Create the private dns zone for App Service private endpoint
module appServiceDnsZone './modules/privateDns.bicep' = {
  name: 'appServiceDnsZone'
  params: {
    dnsZoneName:  'privatelink.azurewebsites.net'
    vnetId: vnetModule.outputs.virtualNetworkId 
  }
}

//Create the SQL Server private endpoint
module sqlPrivateEndPoint './modules/privateEndPoint.bicep' = {
  name: sqlPrivateEndpointName
  params: {
    location: location
    dnsZoneId: sqlDnsZone.outputs.privateDnsId
    privateEndpointName: sqlPrivateEndpointName
    subnetId: privateEndpointSubnet.id
    group: 'sqlServer'
    resourceId: sqlServerModule.outputs.serverId
  }
}

//Create the API App Service private endpoint
module apiAppPrivateEndPoint './modules/privateEndPoint.bicep' = {
  name: apiAppPrivateEndpointName
  params: {
    location: location
    dnsZoneId: appServiceDnsZone.outputs.privateDnsId
    privateEndpointName: apiAppPrivateEndpointName
    subnetId: privateEndpointSubnet.id
    group: 'sites'
    resourceId: apiAppModule.outputs.appId
  }
}

//Create the App Service Plan
module planModule './modules/appServicePlan.bicep' = {
  name: planName
  params: {
    location: location
    planName: planName
  }
}

//Create the Web UI App Service
module webAppModule './modules/appService.bicep' = {
  name: webAppName
  params: {
    location: location
    appName: webAppName
    planId: planModule.outputs.planId
    subnetId: webAppSubnet.id
    appSettings: [{
        name: 'ApiUri'
        value: 'https://${apiAppModule.outputs.appUrl}'
      }
      {
        name: 'ApiAuthUri'
        value: 'api://${apiAuthAppClientId}'
      }
    ]
    authClientId: webAuthAppClientId
    authClientSecret: webAuthAppSecret
  }
}

//Create the API App Service
module apiAppModule './modules/appService.bicep' = {
  name: apiAppName
  params: {
    location: location
    appName: apiAppName
    planId: planModule.outputs.planId
    subnetId: apiAppSubnet.id
    connectionStrings: [{
      connectionString: 'Server=tcp:${sqlServerModule.outputs.serverFullyQualifiedDomainName},1433;Initial Catalog=${sqlDatabaseName};Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;Authentication="Active Directory Default";'
      name: 'SampleApiContext'
      type: 'SQLAzure'
    }]
    authClientId: apiAuthAppClientId
    authClientSecret: apiAuthAppSecret
    isApi: true
  }
}

//Create the SQL Server
module sqlServerModule './modules/sqlServer.bicep' = {
  name: sqlServerName
  params: {
    location: location
    sqlServerName: sqlServerName
    sqlAdminObjectId: sqlAdminObjectId
    alreadyCreated: sqlExists
  }
}

//Create the SQL Database
module databaseModule './modules/sqlDatabase.bicep' = {
  name: sqlDatabaseName
  params: {
    location: location
    sqlServerName: sqlServerModule.outputs.serverName
    databaseName: sqlDatabaseName
  }
}