targetScope = 'subscription'

metadata name = 'Corporate Workload Deployment Stack'
metadata description = 'Subscription-level deployment stack provisioning an enterprise multi-tier platform partitioned across three dedicated Resource Groups (Key Vault, Database, and AppService/Networking) using Azure Verified Modules (AVM).'

// ==========================================
// 1. Workload Identity & Parameters
// ==========================================
@description('Workload identifier (e.g., finance, hr, core).')
@minLength(2)
@maxLength(16)
param workload string = 'finance'

@description('Target environment name.')
@allowed([
  'dev'
  'test'
  'staging'
  'prod'
])
param environment string = 'prod'

@description('Instance index for naming disambiguation.')
@minValue(1)
@maxValue(99)
param instanceIndex int = 1

@description('Deployment stack name.')
param stackName string = 'stack-${workload}-${environment}'

// ==========================================
// 2. Region / Location Parameterization
// ==========================================
@description('Default Azure region fallback for resources.')
param location string = 'westus2'

@description('Azure region for the Key Vault resource group and vault.')
param keyVaultLocation string = location

@description('Azure region for the Database resource group and SQL server.')
param databaseLocation string = location

@description('Azure region for the App Service & Networking resource group.')
param appServiceLocation string = location

// ==========================================
// 3. Key Vault Tier Parameters
// ==========================================
@description('Optional Key Vault name override (3-24 lowercase alphanumeric chars and hyphens).')
param keyVaultName string = ''

@description('SKU name for Key Vault.')
@allowed([
  'standard'
  'premium'
])
param keyVaultSkuName string = 'standard'

@description('Soft delete retention period in days.')
@minValue(7)
@maxValue(90)
param keyVaultSoftDeleteRetentionInDays int = 90

@description('Enable purge protection for Key Vault.')
param keyVaultEnablePurgeProtection bool = true

@description('API App Entra ID Client ID.')
param apiAppAadClientId string = ''

@description('API App Entra ID Client Secret.')
@secure()
param apiAuthAppSecret string = ''

@description('Web App Entra ID Client ID.')
param webAppAadClientId string = ''

@description('Web App Entra ID Client Secret.')
@secure()
param webAppAadClientSecret string = ''

// ==========================================
// 4. Database Tier Parameters
// ==========================================
@description('SQL Database name.')
param sqlDatabaseName string = 'sqldb-${workload}-${environment}'

@description('SKU name for the SQL Database (e.g., Basic, S0, GP_S_Gen5_1).')
param sqlDatabaseSkuName string = 'S0'

@description('SKU tier for the SQL Database (e.g., Basic, Standard, GeneralPurpose).')
param sqlDatabaseSkuTier string = 'Standard'

@description('Compute capacity / DTUs / vCores.')
param sqlDatabaseCapacity int = 10

@description('Maximum database size in bytes.')
param sqlDatabaseMaxSizeBytes int = 268435456000

@description('Enable SQL Database zone redundancy.')
param sqlDatabaseZoneRedundant bool = false

@description('Entra ID Admin Object ID for SQL Server.')
param sqlAdminObjectId string

@description('Entra ID Admin Login/Name for SQL Server.')
param sqlAdminLogin string

@description('Principal type for Entra ID admin.')
@allowed([
  'Application'
  'User'
  'Group'
])
param sqlAdminPrincipalType string = 'Group'

// ==========================================
// 5. App Service Tier Parameters
// ==========================================
@description('App Service Plan SKU name (e.g., B1, S1, P1v3).')
param appServicePlanSku string = 'B1'

@description('App Service Plan worker instance capacity.')
@minValue(1)
param appServicePlanCapacity int = 1

@description('Linux runtime stack for the Next.js Web App.')
param webAppLinuxFxVersion string = 'NODE|22-lts'

@description('Linux runtime stack for the API App.')
param apiAppLinuxFxVersion string = 'DOTNETCORE|10.0'

// ==========================================
// 6. Networking & Governance Parameters
// ==========================================
@description('Spoke VNet address space CIDR.')
param vnetAddressPrefix string = '10.1.0.0/16'

@description('Subnets configuration for spoke VNet.')
param subnets array = [
  {
    name: 'snet-web'
    addressPrefix: '10.1.1.0/24'
    delegation: 'Microsoft.Web/serverFarms'
  }
  {
    name: 'snet-api'
    addressPrefix: '10.1.2.0/24'
    delegation: 'Microsoft.Web/serverFarms'
  }
  {
    name: 'snet-pe'
    addressPrefix: '10.1.3.0/24'
  }
]

@description('Hub connectivity subscription ID.')
param hubSubscriptionId string = '7f493ff6-603b-4254-a6bf-e9acfc665866'

@description('Hub resource group name.')
param hubResourceGroupName string = 'rg-connectivity-hub-prod'

@description('Hub VNet name.')
param hubVnetName string = 'vnet-platform-connectivity-prod'

@description('Resource ID of the existing privatelink.azurewebsites.net Private DNS zone.')
param appServicePrivateDnsZoneId string

@description('Resource ID of the existing privatelink.vaultcore.azure.net Private DNS zone.')
param keyVaultPrivateDnsZoneId string

@description('Resource ID of the existing privatelink.database.windows.net Private DNS zone.')
param databasePrivateDnsZoneId string

@description('Additional tags merged with baseline governance tags.')
param extraTags object = {}

// ==========================================
// Variables & Resource Naming
// ==========================================
var paddedIndex = padLeft(string(instanceIndex), 2, '0')
var nameSeed = '${workload}-${environment}-${paddedIndex}'

// 3 Dedicated Resource Group Names
var rgKeyVaultName = 'rg-kv-${nameSeed}'
var rgDataName = 'rg-data-${nameSeed}'
var rgAppName = 'rg-app-${nameSeed}'

var planName = 'asp-${nameSeed}'
var webAppName = 'app-web-${nameSeed}'
var apiAppName = 'app-api-${nameSeed}'
var sqlServerName = 'sql-${nameSeed}'

var uniqueSuffix = take(uniqueString(subscription().id, rgKeyVaultName), 5)
var resolvedKeyVaultName = !empty(keyVaultName) ? keyVaultName : take('kv-${workload}-${environment}-${paddedIndex}-${uniqueSuffix}', 24)

var hubVnetId = '/subscriptions/${hubSubscriptionId}/resourceGroups/${hubResourceGroupName}/providers/Microsoft.Network/virtualNetworks/${hubVnetName}'

var baselineTags = union(extraTags, {
  workload: workload
  environment: environment
  managedBy: 'bicep-deployment-stack'
  costCenter: toLower('${workload}-${environment}')
})

// ==========================================
// Resource Groups (3 Dedicated RGs)
// ==========================================
resource rgKeyVault 'Microsoft.Resources/resourceGroups@2025-04-01' = {
  name: rgKeyVaultName
  location: keyVaultLocation
  tags: baselineTags
}

resource rgData 'Microsoft.Resources/resourceGroups@2025-04-01' = {
  name: rgDataName
  location: databaseLocation
  tags: baselineTags
}

resource rgApp 'Microsoft.Resources/resourceGroups@2025-04-01' = {
  name: rgAppName
  location: appServiceLocation
  tags: baselineTags
}

// ==========================================
// Architecture Tiers
// ==========================================

// 1. Networking Tier (Spoke VNet, Subnets, Peering) -> rgApp
module networkTier './modules/networkTier.bicep' = {
  name: 'network-${nameSeed}'
  scope: rgApp
  params: {
    location: appServiceLocation
    nameSeed: nameSeed
    vnetAddressPrefix: vnetAddressPrefix
    subnets: subnets
    hubVnetId: hubVnetId
    hubVnetName: hubVnetName
    tags: baselineTags
  }
}

// 2. Key Vault Security Tier (AVM Vault + Secrets + PE + DNS) -> rgKeyVault
module keyVaultTier './modules/keyVaultTier.bicep' = {
  name: 'keyvault-${nameSeed}'
  scope: rgKeyVault
  params: {
    location: keyVaultLocation
    privateEndpointLocation: appServiceLocation
    nameSeed: nameSeed
    keyVaultName: resolvedKeyVaultName
    skuName: keyVaultSkuName
    softDeleteRetentionInDays: keyVaultSoftDeleteRetentionInDays
    enablePurgeProtection: keyVaultEnablePurgeProtection
    apiAuthAppSecret: apiAuthAppSecret
    webAppAadClientSecret: webAppAadClientSecret
    peSubnetId: networkTier.outputs.peSubnetId
    privateDnsZoneId: keyVaultPrivateDnsZoneId
    tags: baselineTags
  }
}

// 3. Database Persistence Tier (AVM SQL Server + DB + PE + DNS) -> rgData
module databaseTier './modules/databaseTier.bicep' = {
  name: 'database-${nameSeed}'
  scope: rgData
  params: {
    location: databaseLocation
    privateEndpointLocation: appServiceLocation
    nameSeed: nameSeed
    sqlServerName: sqlServerName
    sqlDatabaseName: sqlDatabaseName
    sqlAdminObjectId: sqlAdminObjectId
    sqlAdminLogin: sqlAdminLogin
    sqlAdminPrincipalType: sqlAdminPrincipalType
    skuName: sqlDatabaseSkuName
    skuTier: sqlDatabaseSkuTier
    capacity: sqlDatabaseCapacity
    maxSizeBytes: sqlDatabaseMaxSizeBytes
    zoneRedundant: sqlDatabaseZoneRedundant
    peSubnetId: networkTier.outputs.peSubnetId
    privateDnsZoneId: databasePrivateDnsZoneId
    tags: baselineTags
  }
}

// 4. App Service Compute Tier (AVM Plan + AVM Web/API Sites + PE + DNS) -> rgApp
module appTier './modules/appTier.bicep' = {
  name: 'app-${nameSeed}'
  scope: rgApp
  params: {
    location: appServiceLocation
    privateEndpointLocation: appServiceLocation
    nameSeed: nameSeed
    planName: planName
    webAppName: webAppName
    apiAppName: apiAppName
    planSkuName: appServicePlanSku
    planCapacity: appServicePlanCapacity
    webAppLinuxFxVersion: webAppLinuxFxVersion
    apiAppLinuxFxVersion: apiAppLinuxFxVersion
    webSubnetId: networkTier.outputs.webSubnetId
    apiSubnetId: networkTier.outputs.apiSubnetId
    peSubnetId: networkTier.outputs.peSubnetId
    sqlServerFqdn: databaseTier.outputs.serverFullyQualifiedDomainName
    databaseName: databaseTier.outputs.databaseName
    apiAppAadClientId: apiAppAadClientId
    apiAuthAppSecretRef: keyVaultTier.outputs.apiAuthAppSecretRef
    webAppAadClientId: webAppAadClientId
    webAppAadClientSecretRef: keyVaultTier.outputs.webAppAadClientSecretRef
    privateDnsZoneId: appServicePrivateDnsZoneId
    tags: baselineTags
  }
}

// ==========================================
// Outputs
// ==========================================
@description('Primary App/Networking Resource Group ID.')
output resourceGroupId string = rgApp.id

@description('Primary App/Networking Resource Group Name.')
output resourceGroupName string = rgApp.name

@description('Key Vault Resource Group Name.')
output keyVaultResourceGroupName string = rgKeyVault.name

@description('Database Resource Group Name.')
output databaseResourceGroupName string = rgData.name

@description('App Service & Networking Resource Group Name.')
output appResourceGroupName string = rgApp.name

@description('Name of the deployed Key Vault.')
output keyVaultName string = keyVaultTier.outputs.keyVaultName

@description('Vault URI of the deployed Key Vault.')
output keyVaultUri string = keyVaultTier.outputs.vaultUri

@description('Key Vault secret references map for applications.')
output keyVaultSecretReferences object = keyVaultTier.outputs.secretReferences

@description('Full HTTPS URL of the Web App.')
output webAppUrl string = appTier.outputs.webAppUrl

@description('Full HTTPS URL of the API App.')
output apiAppUrl string = appTier.outputs.apiAppUrl

@description('Fully Qualified Domain Name of the Azure SQL Server.')
output sqlServerFqdn string = databaseTier.outputs.serverFullyQualifiedDomainName

@description('Name of the SQL Database.')
output sqlDatabaseName string = databaseTier.outputs.databaseName

@description('Resource ID of the Spoke Virtual Network.')
output vnetId string = networkTier.outputs.vnetId

@description('Deployment Stack name.')
output stackName string = stackName
