param vnetConfiguration object
param location string

resource nsgjumpbox 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: 'nsg-jumpbox'
  location: location
  properties: {
    securityRules: [
      
    ]    
  }
}

resource nsgrunner 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: 'nsg-runner'
  location: location
  properties: {
    securityRules: [
      
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: vnetConfiguration.name
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetConfiguration.addressPrefixe
      ]
    }
    subnets: [
      {
        name: vnetConfiguration.subnets[0].name
        properties: {
          addressPrefix: vnetConfiguration.subnets[0].addressPrefix
        }
      }
      {
        name: vnetConfiguration.subnets[1].name
        properties: {
          addressPrefix: vnetConfiguration.subnets[1].addressPrefix
          networkSecurityGroup: {
            id: nsgjumpbox.id
          }
        }
      }
      {
        name: vnetConfiguration.subnets[2].name
        properties: {
          addressPrefix: vnetConfiguration.subnets[2].addressPrefix
          networkSecurityGroup: {
            id: nsgrunner.id
          }
        }
      }            
    ]
  }
}

output vnetName string = vnet.name
output vnetId string = vnet.id
output subnets array = vnet.properties.subnets
