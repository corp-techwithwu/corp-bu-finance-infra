using './main.bicep'

// ==========================================
// Development Environment Parameters
// ==========================================

// Workload & Environment Identity
param workload = 'finance'
param environment = 'dev'
param instanceIndex = 1
param stackName = 'stack-finance-dev'

// Region & Location Parameterization
param location = 'westus2'
param keyVaultLocation = 'westus2'
param databaseLocation = 'japaneast'
param appServiceLocation = 'westus2'

// Key Vault Tier Configurations
param keyVaultSkuName = 'standard'
param keyVaultSoftDeleteRetentionInDays = 7
param keyVaultEnablePurgeProtection = false
param apiAuthAppClientId = '281c4f44-2d4e-4ae7-8ab5-08cfcd43bb60'
param apiAuthAppSecret = ''

// Database Tier Configurations
param sqlDatabaseName = 'sqldb-finance-dev'
param sqlDatabaseSkuName = 'Free'
param sqlDatabaseSkuTier = 'Free'
param sqlDatabaseCapacity = 5
param sqlDatabaseMaxSizeBytes = 2147483648 // 2 GB
param sqlAdminObjectId = '00000000-0000-0000-0000-000000000002'
param sqlAdminLogin = 'EntraAdmin-Finance-Dev'
param sqlAdminPrincipalType = 'Group'

// App Service Tier Configurations
param appServicePlanSku = 'F1'
param appServicePlanCapacity = 1
param webAppLinuxFxVersion = 'NODE|22-lts'
param apiAppLinuxFxVersion = 'DOTNETCORE|10.0'

// Networking & Hub Configurations
param vnetAddressPrefix = '10.2.0.0/16'
param subnets = [
  {
    name: 'snet-web'
    addressPrefix: '10.2.1.0/24'
    delegation: 'Microsoft.Web/serverFarms'
  }
  {
    name: 'snet-api'
    addressPrefix: '10.2.2.0/24'
    delegation: 'Microsoft.Web/serverFarms'
  }
  {
    name: 'snet-pe'
    addressPrefix: '10.2.3.0/24'
  }
  {
    name: 'snet-keyvault'
    addressPrefix: '10.2.4.0/24'
  }
  {
    name: 'snet-database'
    addressPrefix: '10.2.5.0/24'
  }
]

param hubSubscriptionId = '7f493ff6-603b-4254-a6bf-e9acfc665866'
param hubResourceGroupName = 'rg-connectivity-hub-dev'
param hubVnetName = 'vnet-platform-connectivity-dev'

// Governance & Baseline Tags
param extraTags = {
  Environment: 'Development'
  DataClassification: 'Internal'
  BusinessCriticality: 'Low'
  AutoShutdown: 'True'
}
