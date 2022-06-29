targetScope='subscription'

@description('The location where the resources will be deployed')
param location string

@description('The VNET configuration (hub and spoke)')
param vnetConfiguration object

@secure()
param adminUsername string

@secure()
param adminPassword string

@description('The version of the Ubuntu OS')
param ubuntuVersion string

@description('The size of the VM')
param vmSize string

var hubRgName = 'rg-hub-ase-demo'
var spokeRgAseName = 'rg-spoke-ase-demo'
var spokeRgDbName = 'rg-spoke-db-demo'

var hubsuffix = uniqueString(hubRg.id)
var spokeAseSuffix = uniqueString(spokeAseRg.id)
var spokeDbSuffix = uniqueString(spokeDBRg.id)

resource hubRg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: hubRgName
  location: location
}

resource spokeAseRg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: spokeRgAseName
  location: location
}

resource spokeDBRg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: spokeRgDbName
  location: location
}

module vnetHub 'modules/networking/vnet.hub.bicep' = {
  scope: resourceGroup(hubRg.name)
  name: 'vnetHub'
  params: {
    location: location
    vnetConfiguration: vnetConfiguration.hub
  }
}

module runner 'modules/compute/runner.bicep' = {
  scope: resourceGroup(hubRg.name)
  name: 'runner'
  params: {
    adminPassword: adminPassword
    adminUsername: adminUsername
    location: location
    subnetId: vnetHub.outputs.subnets[2].id
    ubuntuVersion: ubuntuVersion
    vmSize: vmSize
  }
}

module firewall 'modules/firewall/firewall.bicep' = {
  scope: resourceGroup(hubRg.name)
  name: 'firewall'
  params: {
    location: location
    subnetId: vnetHub.outputs.subnets[0].id
    suffix: hubsuffix
    subnetASECIDR: vnetConfiguration.spoke.subnets[0].properties.addressPrefix
    subnetSpokeDBCIDR: vnetConfiguration.spokeDB.addressPrefixe
  }
}

module routeTable 'modules/networking/routeTable.bicep' = {
  scope: resourceGroup(spokeAseRg.name)
  name: 'routeTable'
  params: {
    fwPrivateIP: firewall.outputs.privateIp
    fwPublicIP: firewall.outputs.publicIp
    location: location
  }
}

module vnetSpoke 'modules/networking/vnet.spoke.bicep' = {
  scope: resourceGroup(spokeAseRg.name)
  name: 'vnetSpoke'
  params: {
    location: location
    vnetConfiguration: vnetConfiguration.spoke
    routeTableId: routeTable.outputs.routeTableId
  }
}

module vnetSpokeDB 'modules/networking/vnet.spoke.db.bicep' = {
  scope: resourceGroup(spokeDBRg.name)
  name: 'vnetSpokeDB'
  params: {
    location: location
    vnetConfiguration: vnetConfiguration.spokeDB
  }
}

module peeringhubToSpoke 'modules/networking/peering.bicep' = {
  scope: resourceGroup(hubRg.name)
  name: 'peeringhubToSpoke'
  params: {
    peeringName: '${vnetHub.outputs.vnetName}/hub-to-spoke'
    remoteVnetId: vnetSpoke.outputs.vnetId
  }
}

module peeringhubToDb 'modules/networking/peering.bicep' = {
  scope: resourceGroup(hubRg.name)
  name: 'peeringhubToDb'
  params: {
    peeringName: '${vnetHub.outputs.vnetName}/hub-to-spoke-db'
    remoteVnetId: vnetSpokeDB.outputs.vnetId
  }
}

module peeringspokeASE 'modules/networking/peering.bicep' = {
  scope: resourceGroup(spokeAseRg.name)
  name: 'peeringspokeASE'
  params: {
    peeringName: '${vnetSpoke.outputs.vnetName}/spoke-to-hub'
    remoteVnetId: vnetHub.outputs.vnetId
  }
}

module peeringspokeDB 'modules/networking/peering.bicep' = {
  scope: resourceGroup(spokeDBRg.name)
  name: 'peeringspokeDB'
  params: {
    peeringName: '${vnetSpokeDB.outputs.vnetName}/spoke-to-hub'
    remoteVnetId: vnetHub.outputs.vnetId
  }
}

module ase 'modules/ase/ase.bicep' = {
  scope: resourceGroup(spokeAseRg.name)
  name: 'ase'
  params: {
    location: location
    subnetId: vnetSpoke.outputs.subnets[0].id
    suffix: spokeAseSuffix
  }
}

module dnsZone 'modules/DNS/privatezone.ase.bicep'= {
  scope: resourceGroup(spokeAseRg.name)
  name: 'dnsZone'
  params: {
    aseName: ase.outputs.aseName
    hubVnetId: vnetHub.outputs.vnetId
    vnetNameSpoke: vnetSpoke.outputs.vnetName
    asePrivateIp: ase.outputs.asePrivateIp
    privateIpRunner: runner.outputs.privateIps
    runnerVmName: runner.outputs.vmName
    spokeVnetId: vnetSpoke.outputs.vnetId
    vnetNameHub: vnetHub.outputs.vnetName
  }
}

module appServicePlan 'modules/webapp/appservice.bicep' = {
  scope: resourceGroup(spokeAseRg.name)
  name: 'appServicePlan'
  params: {
    aseId: ase.outputs.aseId
    location: location
    suffix: spokeAseSuffix
  }
}

module web 'modules/webapp/webapp.bicep' = {
  scope: resourceGroup(spokeAseRg.name)
  name: 'web'
  params: {
    appServiceId: appServicePlan.outputs.appserviceId
    aseName: ase.outputs.aseName
    aseId: ase.outputs.aseId
    location: location
    suffix: spokeAseSuffix
    cacheName: cache.outputs.cacheName
    cacheResourceGroup: spokeDBRg.name
    appServiceWebTodoId: appServicePlan.outputs.appserviceTodoId
  }
}

module cache 'modules/cache/redis.bicep' = {
  scope: resourceGroup(spokeDBRg.name)
  name: 'cache'
  params: {
    location: location
    suffix: spokeDbSuffix
  }
}

module privateEndpointCache 'modules/DNS/privatezone.redis.bicep' = {
  scope: resourceGroup(spokeDBRg.name)
  name: 'privateEndpointCache'
  params: {
    cacheId: cache.outputs.id
    vnetNameHub: vnetHub.outputs.vnetName
    hubVnetId: vnetHub.outputs.vnetId
    location: location
    privateIpRunner: runner.outputs.privateIps
    runnerVmName: runner.outputs.vmName
    spokeDbVnetId: vnetSpokeDB.outputs.vnetId
    spokeDBSubnetId: vnetSpokeDB.outputs.subnets[0].id
    vnetNameSpokeDB: vnetSpokeDB.outputs.vnetName
    spokeASEVnetId: vnetSpoke.outputs.vnetId
    vnetNameSpokeASE: vnetSpoke.outputs.vnetName
  }
}

module workspace 'modules/analytics/workspace.bicep' = {
  scope: resourceGroup(hubRg.name)
  name: 'workspace'
  params: {
    location: location
    suffix: hubsuffix
  }
}

output weatherApiName string = web.outputs.weatherApiName
output fibonacciApiName string = web.outputs.fibonacciApiName

output gatewaySubnetId string = vnetSpoke.outputs.subnets[1].id

output weatherApiAppFQDN string = web.outputs.weatherApiAppFQDN
output fibonacciApiAppFQDN string = web.outputs.fibonacciApiAppFQDN

output todoWebAppName string = web.outputs.todoWebAppName
output todoWebAppFQDN string = web.outputs.todoWebAppFQDN

output spokeResourceGroupName string = spokeRgAseName
