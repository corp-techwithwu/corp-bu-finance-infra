@description('Azure region for the Key Vault.')
param location string = resourceGroup().location

@description('Name of the Key Vault (3-24 lowercase alphanumeric characters and hyphens).')
@minLength(3)
@maxLength(24)
param keyVaultName string

@description('Web App Entra ID Client ID.')
param webAuthAppClientId string = ''

@description('Web App Entra ID Client Secret.')
@secure()
param webAuthAppSecret string = ''

@description('API App Entra ID Client ID.')
param apiAuthAppClientId string = ''

@description('API App Entra ID Client Secret.')
@secure()
param apiAuthAppSecret string = ''

@description('Tags applied to the Key Vault.')
param tags object = {}

var secretsMap = {
  webAuthAppClientId: webAuthAppClientId
  webAuthAppSecret: webAuthAppSecret
  apiAuthAppClientId: apiAuthAppClientId
  apiAuthAppSecret: apiAuthAppSecret
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enabledForDeployment: false
    enabledForTemplateDeployment: true
    enabledForDiskEncryption: false
    publicNetworkAccess: 'Enabled'
  }
}

resource kvSecrets 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = [for item in items(secretsMap): if (!empty(item.value)) {
  parent: keyVault
  name: item.key
  properties: {
    value: item.value
  }
}]

@description('Resource ID of the Key Vault.')
output keyVaultId string = keyVault.id

@description('Name of the Key Vault.')
output keyVaultName string = keyVault.name
