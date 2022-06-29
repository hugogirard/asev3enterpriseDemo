param location string
param suffix string
param appServiceId string
param appServiceWebTodoId string
param aseId string
param aseName string

param cacheName string
param cacheResourceGroup string


resource cache 'Microsoft.Cache/redis@2021-06-01' existing = {
  name: cacheName
  scope: resourceGroup(cacheResourceGroup)
}

//var cacheCnxString = listKey(cacheId, cacheApiVersion).primaryKey

var cacheCnxString = '${cacheName}.redis.cache.windows.net:6380,password=${cache.listKeys().primaryKey},ssl=True,abortConnect=False'

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

resource todoWeb 'Microsoft.Web/sites@2021-03-01' = {
  name: 'todoweb-${suffix}'
  location: location
  properties: {
    siteConfig: {
      linuxFxVersion: 'DOTNETCORE|6.0'
    }
    serverFarmId: appServiceWebTodoId
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

output todoWebAppName string = todoWeb.name
output todoWebAppFQDN string = '${todoWeb.name}.${aseName}.appserviceenvironment.net'
