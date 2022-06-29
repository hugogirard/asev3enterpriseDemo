param location string
param suffix string
param aseId string

var appPlannameOne = 'asp-${suffix}'
var appPlannameTwo = 'asp-todo-${suffix}'

resource appservice 'Microsoft.Web/serverfarms@2021-03-01' = {
  name: appPlannameOne
  location: location
  kind: 'linux'
  properties: {
    reserved: true
    zoneRedundant: false
    hostingEnvironmentProfile: {
      id: aseId
    }    
  }
  sku: {
    tier: 'IsolatedV2'
    name: 'I1V2'
  }
}

resource appservicePlanTodoWeb 'Microsoft.Web/serverfarms@2021-03-01' = {
  name: appPlannameTwo
  location: location
  kind: 'linux'
  properties: {
    reserved: true
    zoneRedundant: false
    hostingEnvironmentProfile: {
      id: aseId
    }    
  }
  sku: {
    tier: 'IsolatedV2'
    name: 'I1V2'
  }
}


output appserviceId string = appservice.id
output appserviceTodoId string = appservicePlanTodoWeb.id
