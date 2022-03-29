param location string
param suffix string
param appServiceId string
param aseId string
param aseName string

param cacheId string
param cacheApiVersion string


//var cacheCnxString = listKey(cacheId, cacheApiVersion).primaryKey

var cacheCnxString = 'na'

resource weatherApi 'Microsoft.Web/sites@2021-03-01' = {
  name: 'weatherapi-${suffix}'
  location: location
  properties: {
    siteConfig: {
      linuxFxVersion: 'DOTNETCORE|6.0'
    }
    serverFarmId: appServiceId
    hostingEnvironmentProfile: {
      id: aseId
    }
  }
}

resource fibonacciApi 'Microsoft.Web/sites@2021-03-01' = {
  name: 'fibonacciApi-${suffix}'
  location: location
  properties: {
    siteConfig: {
      linuxFxVersion: 'DOTNETCORE|6.0'      
      appSettings: [
        {
          name: 'RedisCnxString'
          value: cacheCnxString
        }
      ]
    }      
    serverFarmId: appServiceId
    hostingEnvironmentProfile: {
      id: aseId
    }
  }
}

output weatherApiName string = weatherApi.name
output weatherApiAppFQDN string = '${weatherApi.name}.${aseName}.appserviceenvironment.net'

output fibonacciApiName string = fibonacciApi.name
output fibonacciApiAppFQDN string = '${fibonacciApi.name}.${aseName}.appserviceenvironment.net'
