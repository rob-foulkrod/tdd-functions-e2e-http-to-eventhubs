targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
@allowed(['australiaeast', 'eastasia', 'eastus', 'eastus2', 'northeurope', 'southcentralus', 'southeastasia', 'swedencentral', 'uksouth', 'westus2', 'eastus2euap'])
@metadata({
  azd: {
    type: 'location'
  }
})
param location string

// Optional parameters to override the default azd resource naming conventions. Update the main.parameters.json file to provide values. e.g.,:
param apiServiceName string = ''
param applicationInsightsDashboardName string = ''
param applicationInsightsName string = ''
param appServicePlanName string = ''
param logAnalyticsName string = ''
param loadTestName string = ''
param resourceGroupName string = ''
param storageAccountName string = ''
param eventHubName string = ''
param eventHubNamespaceName string = ''
param vNetName string = ''
param ehSubnetName string = ''
param appSubnetName string = ''
param loadSubnetName string = ''

@description('Id of the user or app to assign application roles')
param principalId string = ''

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = { 
  'azd-env-name': environmentName
  SecurityControl: 'Ignore'
}
// Generate a unique function app name if one is not provided.
var appName = !empty(apiServiceName) ? apiServiceName : '${abbrs.webSitesFunctions}${environmentName}${resourceToken}'
// Generate a unique container name that will be used for deployments.
var deploymentStorageContainerName = 'app-package-${take(appName, 32)}-${take(resourceToken, 7)}'

// Organize resources in a resource group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

// The application backend powered by Flex Consumption Function
module api './app/api.bicep' = {
  name: 'api'
  scope: rg
  params: {
    name: appName
    serviceName: 'api'
    location: location
    tags: tags
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    appServicePlanId: apiAppServicePlan.outputs.id
    runtimeName: 'dotnet-isolated'
    runtimeVersion: '8.0'
    instanceMemoryMB: 2048
    maximumInstanceCount: 250
    storageAccountName: storage.outputs.name
    deploymentStorageContainerName: deploymentStorageContainerName
    appSettings: {
    }
    virtualNetworkSubnetId: serviceVirtualNetwork.outputs.appSubnetID
    eventHubName: eventHubs.outputs.eventHubName
    eventHubFQDN: eventHubs.outputs.namespaceFQDN
  }
}

// Create an App Service Plan to group applications under the same payment plan and SKU
module apiAppServicePlan 'core/host/appserviceplan.bicep' = {
  name: 'apiAppServicePlan'
  scope: rg
  params: {
    name: !empty(appServicePlanName) ? appServicePlanName : '${abbrs.webServerFarms}api${resourceToken}'
    location: location
    tags: tags
    sku: {
      name: 'FC1'
      tier: 'FlexConsumption'
      size: 'FC'
      family: 'FC'
    }
    reserved: true
  }
}

// Backing storage for Azure functions backend API
module storage './core/storage/storage-account.bicep' = {
  name: 'storage'
  scope: rg
  params: {
    name: !empty(storageAccountName) ? storageAccountName : '${abbrs.storageStorageAccounts}${resourceToken}'
    location: location
    tags: tags
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      defaultAction: 'Deny'
    }
    containers: [{name: deploymentStorageContainerName}]
  }
}

//Storage Blob Data Owner role, Storage Blob Data Contributor role, Storage Table Data Contributor role
// Allow access from API to storage account using a managed identity and Storage Blob Data Contributor and Data Owner role
var roleIds = ['b7e6dc6d-f1e8-4753-8033-0f276bb0955b', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe', '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3']
var principalIds = [api.outputs.SERVICE_API_IDENTITY_PRINCIPAL_ID, principalId]
module storageBlobDataOwnerRoleDefinitionApi 'app/storage-Access.bicep' = [for roleId in roleIds: {
  name: 'blobDataOwner${roleId}'
  scope: rg
  params: {
    storageAccountName: storage.outputs.name
    roleId: roleId
    principalIds: principalIds
  }
}]

// Event Hubs
module eventHubs 'core/message/eventhubs.bicep' = {
  name: 'eventHubs'
  scope: rg
  params: {
    location: location
    tags: tags
    eventHubNamespaceName: !empty(eventHubNamespaceName) ? eventHubNamespaceName : '${abbrs.eventHubNamespaces}${resourceToken}'
    eventHubName: !empty(eventHubName) ? eventHubName : '${abbrs.eventHubNamespacesEventHubs}${resourceToken}'
  }
}

// Azure Event Hubs Data Sender role
var eventHubsSenderRoleDefinitionId  = '2b629674-e913-4c01-ae53-ef4638d8f975'
module eventHubsSenderRoleAssignmentApi 'app/eventhubs-Access.bicep' = {
  name:'eventHubsSenderRoleAssignment'
  scope: rg
  params: {
    eventHubsNamespaceName: eventHubs.outputs.eventHubNamespaceName
    eventHubName: eventHubs.outputs.eventHubName
    roleDefinitionID: eventHubsSenderRoleDefinitionId
    principalIDs: [api.outputs.SERVICE_API_IDENTITY_PRINCIPAL_ID, principalId]
  }
}

// Virtual Network & private endpoint
module serviceVirtualNetwork 'app/vnet.bicep' = {
  name: 'serviceVirtualNetwork'
  scope: rg
  params: {
    location: location
    tags: tags
    vNetName: !empty(vNetName) ? vNetName : '${abbrs.networkVirtualNetworks}${resourceToken}'
    ehSubnetName: !empty(ehSubnetName) ? ehSubnetName : '${abbrs.networkVirtualNetworksSubnets}eh${resourceToken}'  
    appSubnetName: !empty(appSubnetName) ? appSubnetName : '${abbrs.networkVirtualNetworksSubnets}app${resourceToken}' 
    loadSubnetName: !empty(loadSubnetName) ? loadSubnetName : '${abbrs.networkVirtualNetworksSubnets}load${resourceToken}' 
    
  }
}

module storagePrivateEndpoint 'app/storage-PrivateEndpoint.bicep' = {
  name: 'storagePrivateEndpoint'
  scope: rg
  params: {
    location: location
    tags: tags
    virtualNetworkName: !empty(vNetName) ? vNetName : '${abbrs.networkVirtualNetworks}${resourceToken}'
    subnetName: serviceVirtualNetwork.outputs.stSubnetName
    resourceName: storage.outputs.name
  }
}

module servicePrivateEndpoint 'core/networking/privateEndpoint.bicep' = {
  name: 'servicePrivateEndpoint'
  scope: rg
  params: {
    location: location
    tags: tags
    virtualNetworkName: !empty(vNetName) ? vNetName : '${abbrs.networkVirtualNetworks}${resourceToken}'
    subnetName: !empty(ehSubnetName) ? ehSubnetName : '${abbrs.networkVirtualNetworksSubnets}eh${resourceToken}' 
    ehNamespaceId: eventHubs.outputs.namespaceId
  }
}

// Monitor application with Azure Monitor
module monitoring './core/monitor/monitoring.bicep' = {
  name: 'monitoring'
  scope: rg
  params: {
    location: location
    tags: tags
    logAnalyticsName: !empty(logAnalyticsName) ? logAnalyticsName : '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    applicationInsightsName: !empty(applicationInsightsName) ? applicationInsightsName : '${abbrs.insightsComponents}${resourceToken}'
    applicationInsightsDashboardName: !empty(applicationInsightsDashboardName) ? applicationInsightsDashboardName : '${abbrs.portalDashboards}${resourceToken}'
  }
}
module loadTest 'app/loadtesting.bicep' = {
  name: 'loadTestDeployment${resourceToken}'
  scope: rg
  params: {
    loadTestName: !empty(loadTestName) ? loadTestName : 'loadtesting${resourceToken}'
    location: location
    tags: tags
  }
}

// App outputs
output APPLICATIONINSIGHTS_CONNECTION_STRING string = monitoring.outputs.applicationInsightsConnectionString
output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output SERVICE_API_BASE_URL string = api.outputs.SERVICE_API_URI
output RESOURCE_GROUP string = rg.name
output AZURE_FUNCTION_NAME string = api.outputs.SERVICE_API_NAME
output LOADTESTING_NAME string = loadTest.outputs.loadTestName
output LOAD_SUBNET_ID string = serviceVirtualNetwork.outputs.loadSubnetID
