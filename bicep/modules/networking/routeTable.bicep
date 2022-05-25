param location string
param fwPrivateIP string
param fwPublicIP string

resource aseRouteTable 'Microsoft.Network/routeTables@2021-05-01' = {
  name: 'rt-ase'
  location: location
  properties: {    
    routes: [
      {
        name: 'ase-to-fw'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: fwPrivateIP
        }
      }
    ]
  }
}

output routeTableId string = aseRouteTable.id
