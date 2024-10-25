param eventHubName string
param eventHubNamespaceName string
@description('Specifies the messaging tier for Event Hub Namespace.')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param eventHubSku string = 'Premium'
param eventHubCapacity int = 1
param location string = resourceGroup().location
param tags object = {}

resource eventHubNamespace 'Microsoft.EventHub/namespaces@2024-05-01-preview' = {
  name: eventHubNamespaceName
  location: location
  tags: tags
  sku: {
    name: eventHubSku
    tier: eventHubSku
    capacity: eventHubCapacity
  }
  properties: {
    publicNetworkAccess: 'Disabled'
  }
}

resource eventHub 'Microsoft.EventHub/namespaces/eventhubs@2024-05-01-preview' = {
  parent: eventHubNamespace
  name: eventHubName
  properties: {
    retentionDescription: {
      cleanupPolicy: 'Delete'
      retentionTimeInHours: 24
    }
    messageRetentionInDays: 1
    partitionCount: 100

  }
}

resource eventHubSendAccessKey 'Microsoft.EventHub/namespaces/authorizationrules@2023-01-01-preview' = {
  parent: eventHubNamespace
  name: 'SendAccessKey'
  properties: {
    rights: [
      'Send'
    ]
  }
}

output namespaceId string = eventHubNamespace.id
output namespaceFQDN string = '${eventHubNamespace.name}.servicebus.windows.net'
output eventHubNamespaceName string = eventHubNamespace.name
output eventHubName string = eventHub.name
output eventHubSendAccessKeyId string = eventHubSendAccessKey.id
