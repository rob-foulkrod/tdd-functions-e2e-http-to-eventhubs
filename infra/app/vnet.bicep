@description('Specifies the name of the virtual network.')
param vNetName string

@description('Specifies the location.')
param location string = resourceGroup().location

@description('Specifies the name of the subnet for the Event Hubs private endpoint.')
param ehSubnetName string = 'eh'

@description('Specifies the name of the subnet for the Load testing subnet.')
param loadSubnetName string = 'eh'

@description('Specifies the name of the subnet for Function App virtual network integration.')
param appSubnetName string = 'app'

@description('Specifies the name of the subnet for the storage account.')
param stSubnetName string = 'st'

param tags object = {}


resource virtualNetwork 'Microsoft.Network/virtualNetworks@2024-01-01' = {
  name: vNetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    encryption: {
      enabled: false
      enforcement: 'AllowUnencrypted'
    }
    subnets: [
      {
        name: ehSubnetName
        id: resourceId('Microsoft.Network/virtualNetworks/subnets', vNetName, ehSubnetName)
        properties: {
          addressPrefixes: [
            '10.0.1.0/24'
          ]
          delegations: []
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
        type: 'Microsoft.Network/virtualNetworks/subnets'
      }
      {
        name: appSubnetName
        id: resourceId('Microsoft.Network/virtualNetworks/subnets', vNetName, appSubnetName)
        properties: {
          addressPrefixes: [
            '10.0.2.0/23'
          ]
          delegations: [
            {
              name: 'delegation'
              id: resourceId('Microsoft.Network/virtualNetworks/subnets/delegations', vNetName, 'app', 'delegation')
              properties: {
                //Microsoft.App/environments is the correct delegation for Flex Consumption VNet integration
                serviceName: 'Microsoft.App/environments'
              }
              type: 'Microsoft.Network/virtualNetworks/subnets/delegations'
            }
          ]
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
        type: 'Microsoft.Network/virtualNetworks/subnets'
      }
      {
        name: stSubnetName
        id: resourceId('Microsoft.Network/virtualNetworks/subnets', vNetName, stSubnetName)
        properties: {
          addressPrefixes: [
            '10.0.4.0/24'
          ]
          delegations: []
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
        type: 'Microsoft.Network/virtualNetworks/subnets'
      }
      {
        name: loadSubnetName
        id: resourceId('Microsoft.Network/virtualNetworks/subnets', vNetName, loadSubnetName)
        properties: {
          addressPrefixes: [
            '10.0.5.0/24'
          ]
          delegations: []
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
        type: 'Microsoft.Network/virtualNetworks/subnets'
      }
    ]
    virtualNetworkPeerings: []
    enableDdosProtection: false
  }
}

output ehSubnetName string = virtualNetwork.properties.subnets[0].name
output ehSubnetID string = virtualNetwork.properties.subnets[0].id
output appSubnetName string = virtualNetwork.properties.subnets[1].name
output appSubnetID string = virtualNetwork.properties.subnets[1].id
output stSubnetName string = virtualNetwork.properties.subnets[2].name
output stSubnetID string = virtualNetwork.properties.subnets[2].id
output loadSubnetName string = virtualNetwork.properties.subnets[3].name
output loadSubnetID string = virtualNetwork.properties.subnets[3].id


