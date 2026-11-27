@description('Azure region for the Web App.')
param location string = resourceGroup().location

@description('Name of the Web App.')
@minLength(2)
@maxLength(60)
param appName string

@description('Resource ID of the App Service Plan.')
param planId string

@description('Linux runtime stack (e.g., NODE|22-lts or DOTNETCORE|10.0).')
param linuxFxVersion string = 'DOTNETCORE|10.0'

@description('Optional subnet resource ID for VNet regional integration.')
param subnetId string = ''

@description('Application settings array ({ name, value }). Supports @Microsoft.KeyVault(...) references.')
param appSettings array = []

@description('Connection strings array ({ name, connectionString, type }).')
param connectionStrings array = []

@description('Enable Microsoft Entra ID (Easy Auth v2) authentication.')
param useAuth bool = true

@description('Entra ID App Registration Client ID (plain value or @Microsoft.KeyVault(...) reference).')
param authClientId string = ''

@description('Entra ID App Registration Client Secret (plain value or @Microsoft.KeyVault(...) reference).')
@secure()
param authClientSecret string = ''

@description('Allowed token audiences for Easy Auth.')
param authAllowedAudiences array = []

@description('Additional Entra ID login parameters.')
param loginParameters array = []

@description('Paths excluded from Easy Auth.')
param excludedPaths array = []

@description('Whether this app acts as a backend API (returns 401 instead of redirecting to login).')
param isApi bool = false

@description('Always on setting for the site.')
param alwaysOn bool = true

@description('Tags applied to the resource.')
param tags object = {}

@description('Disable public network access when using Private Endpoints.')
param disablePublicNetworkAccess bool = true

var clientSecretSettingName = 'MICROSOFT_PROVIDER_AUTHENTICATION_SECRET'

var secretAppSetting = (!empty(authClientSecret)) ? [
  {
    name: clientSecretSettingName
    value: authClientSecret
  }
] : []

var mergedAppSettings = union(appSettings, secretAppSetting)

module appServiceAvm 'br/public:avm/res/web/site:0.15.1' = {
  name: 'avm-app-${appName}'
  params: {
    name: appName
    location: location
    tags: tags
    kind: 'app'
    serverFarmResourceId: planId
    virtualNetworkSubnetId: !empty(subnetId) ? subnetId : null
    httpsOnly: true
    publicNetworkAccess: disablePublicNetworkAccess ? 'Disabled' : 'Enabled'
    managedIdentities: {
      systemAssigned: true
    }
    siteConfig: {
      linuxFxVersion: linuxFxVersion
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      vnetRouteAllEnabled: true
      alwaysOn: alwaysOn
      http20Enabled: true
      httpLoggingEnabled: true
      detailedErrorLoggingEnabled: true
      failedRequestsTracingEnabled: true
      appSettings: mergedAppSettings
      connectionStrings: connectionStrings
    }
  }
}

resource authSettings 'Microsoft.Web/sites/config@2025-03-01' = if (useAuth && !empty(authClientId)) {
  // checkov:skip=CKV_AZURE_222: Public network access is disabled on the parent site by appServiceAvm.
  // checkov:skip=CKV_AZURE_63: False positive — resource is authsettingsV2. HTTP logging is enabled via appServiceAvm params.siteConfig.httpLoggingEnabled (AVM renders Microsoft.Web/sites/config/logs)
  // checkov:skip=CKV_AZURE_88: False positive — this is the authsettingsV2 sub-resource, not the site. Azure Files mounts (if needed) belong on the parent site rendered by AVM
  // checkov:skip=CKV_AZURE_13: False positive — Easy Auth v2 IS enabled here; Checkov can't correlate this sub-resource back to the AVM-rendered parent site.
  // checkov:skip=CKV_AZURE_66: False positive - resource is authsettingsV2. failed request tracing has been enabled in the appServiceAvm
  // checkov:skip=CKV_AZURE_80: False positive - resource is authsettingsV2. OS version is configured in the appServiceAvm
  // checkov:skip=CKV_AZURE_65: False positive - resource is authsettingsV2. detailed error messages should be controlled in the appServiceAvm
  name: '${appName}/authsettingsV2'
  dependsOn: [
    appServiceAvm
  ]
  properties: {
    identityProviders: {
      azureActiveDirectory: {
        enabled: true
        registration: {
          clientId: authClientId
          clientSecretSettingName: clientSecretSettingName
          openIdIssuer: '${az.environment().authentication.loginEndpoint}${tenant().tenantId}/v2.0'
        }
        validation: {
          allowedAudiences: authAllowedAudiences
        }
        login: {
          loginParameters: loginParameters
        }
      }
    }
    globalValidation: {
      redirectToProvider: 'AzureActiveDirectory'
      unauthenticatedClientAction: isApi ? 'Return401' : 'RedirectToLoginPage'
      excludedPaths: excludedPaths
    }
    login: {
      tokenStore: {
        enabled: true
      }
    }
  }
}

@description('Resource ID of the App Service.')
output appId string = appServiceAvm.outputs.resourceId

@description('Default hostname of the App Service.')
output appUrl string = appServiceAvm.outputs.defaultHostname

@description('System-assigned managed identity principal ID.')
output principalId string = appServiceAvm.outputs.systemAssignedMIPrincipalId
