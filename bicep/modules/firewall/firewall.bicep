param location string
param suffix string
param subnetFirewallId string
param subnetManagementId string

param subnetASECIDR string
param subnetSpokeDBCIDR string

resource pipPublicEndpoint 'Microsoft.Network/publicIPAddresses@2021-05-01' = {
  name: 'pip-fw-${suffix}'
  location: location
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
}

resource pipManagementEndpoint 'Microsoft.Network/publicIPAddresses@2021-05-01' = {
  name: 'pip-mgt-fw-${suffix}'
  location: location
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
}

resource firewallPolicies 'Microsoft.Network/firewallPolicies@2021-05-01' = {
  name: 'fw-policy-${suffix}'
  location: location
  properties: {
    sku: {
      tier: 'Basic'
    }
    threatIntelMode: 'Alert'
  }
}

// resource defaultApplicationGroups 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2021-05-01' = {
//   name: '${firewallPolicies.name}/DefaultApplicationRuleCollectionGroup'
//   properties: {
//     priority: 300
//     ruleCollections: [
//       {
//         ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
//         action: {
//           type: 'Deny'
//         }
//         rules: [
          
//         ]
//         name: 'Deny'
//         priority: 100
//       }
//     ]
//   }
// }



resource firewall 'Microsoft.Network/azureFirewalls@2021-05-01' = {
  name: 'fw-${suffix}'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          subnet: {
            id: subnetFirewallId
          }
          publicIPAddress: {
            id: pipPublicEndpoint.id
          }
        }
      }
    ]
    sku: {
      tier: 'Basic'
    }
    managementIpConfiguration: {
      name: 'managementIpConfig'
      properties: {
        subnet: {
          id: subnetManagementId        
        }
        publicIPAddress: {
          id: pipManagementEndpoint.id
        }
      }
    }
    firewallPolicy: {
      id: firewallPolicies.id
    }
  }
}

output privateIp string = firewall.properties.ipConfigurations[0].properties.privateIPAddress
output publicIp string = pipPublicEndpoint.properties.ipAddress
