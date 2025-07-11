targetScope = 'subscription'

metadata name = 'Using large parameter set'
metadata description = 'This instance deploys the module with most of its features enabled.'

// ========== //
// Parameters //
// ========== //

@description('Optional. The name of the resource group to deploy for testing purposes.')
@maxLength(90)
param resourceGroupName string = 'dep-${namePrefix}-digitaltwins.digitaltwinsinstances-${serviceShort}-rg'

@description('Optional. The location to deploy resources to.')
param resourceLocation string = deployment().location

@description('Optional. A short identifier for the kind of deployment. Should be kept short to not run into resource-name length-constraints.')
param serviceShort string = 'dtdmax'

@description('Optional. A token to inject into the name of each resource.')
param namePrefix string = '#_namePrefix_#'

// ============ //
// Dependencies //
// ============ //

// General resources
// =================
resource resourceGroup 'Microsoft.Resources/resourceGroups@2025-04-01' = {
  name: resourceGroupName
  location: resourceLocation
}

module nestedDependencies 'dependencies.bicep' = {
  scope: resourceGroup
  name: '${uniqueString(deployment().name, resourceLocation)}-nestedDependencies'
  params: {
    location: resourceLocation
    virtualNetworkName: 'dep-${namePrefix}-vnet-${serviceShort}'
    managedIdentityName: 'dep-${namePrefix}-msi-${serviceShort}'
    eventHubName: 'dep-${serviceShort}-evh-01'
    eventHubNamespaceName: 'dep-${serviceShort}-evhns-01'
    serviceBusNamespaceName: 'dep-${serviceShort}-sb-01'
    eventGridTopicName: 'dep-${serviceShort}-evgt-01'
  }
}

// Diagnostics
// ===========
module diagnosticDependencies '../../../../../../../utilities/e2e-template-assets/templates/diagnostic.dependencies.bicep' = {
  scope: resourceGroup
  name: '${uniqueString(deployment().name, resourceLocation)}-diagnosticDependencies'
  params: {
    storageAccountName: 'dep${namePrefix}diasa${serviceShort}03'
    logAnalyticsWorkspaceName: 'dep-${namePrefix}-law-${serviceShort}'
    eventHubNamespaceEventHubName: 'dep-${namePrefix}-evh-${serviceShort}01'
    eventHubNamespaceName: 'dep-${namePrefix}-evhns-${serviceShort}01'
    location: resourceLocation
  }
}

// ============== //
// Test Execution //
// ============== //

@batchSize(1)
module testDeployment '../../../main.bicep' = [
  for iteration in ['init', 'idem']: {
    scope: resourceGroup
    name: '${uniqueString(deployment().name, resourceLocation)}-test-${serviceShort}-${iteration}'
    params: {
      name: '${namePrefix}${serviceShort}001'
      location: resourceLocation
      managedIdentities: {
        systemAssigned: true
        userAssignedResourceIds: [
          nestedDependencies.outputs.managedIdentityResourceId
        ]
      }
      endpoints: [
        {
          name: 'EventGridPrimary'
          properties: {
            endpointType: 'EventGrid'
            eventGridTopicResourceId: nestedDependencies.outputs.eventGridTopicResourceId
          }
        }
        {
          name: 'IdentityBasedEndpoint'
          properties: {
            endpointType: 'EventHub'
            authentication: {
              eventHubResourceId: nestedDependencies.outputs.eventHubNamespaceEventHubResourceId
              type: 'IdentityBased'
              managedIdentities: {
                userAssignedResourceId: nestedDependencies.outputs.managedIdentityResourceId
              }
            }
          }
        }
        {
          name: 'KeyBasedEndpoint'
          properties: {
            endpointType: 'EventHub'
            authentication: {
              eventHubAuthorizationRuleName: nestedDependencies.outputs.eventHubNamespaceEventHubAuthorizationRuleName
              eventHubResourceId: nestedDependencies.outputs.eventHubNamespaceEventHubResourceId
              type: 'KeyBased'
            }
          }
        }
        {
          name: 'IdentityBasedServiceBusPrimaryEndpoint'
          properties: {
            endpointType: 'ServiceBus'
            authentication: {
              type: 'IdentityBased'
              serviceBusNamespaceTopicResourceId: nestedDependencies.outputs.serviceBusNamespaceTopicResourceId
              managedIdentities: {
                userAssignedResourceId: nestedDependencies.outputs.managedIdentityResourceId
              }
            }
          }
        }
        {
          name: 'IdentityBasedServiceBusSecondaryEndpoint'
          properties: {
            endpointType: 'ServiceBus'
            authentication: {
              type: 'IdentityBased'
              serviceBusNamespaceTopicResourceId: nestedDependencies.outputs.serviceBusNamespaceTopicResourceId
              managedIdentities: {
                systemAssigned: true
              }
            }
          }
        }
        {
          name: 'KeyBasedServiceBusEndpoint'
          properties: {
            authentication: {
              type: 'KeyBased'
              serviceBusNamespaceTopicAuthorizationRuleName: nestedDependencies.outputs.serviceBusNamespaceTopicAuthorizationRuleName
              serviceBusNamespaceTopicResourceId: nestedDependencies.outputs.serviceBusNamespaceTopicResourceId
            }
            endpointType: 'ServiceBus'
          }
        }
      ]
      diagnosticSettings: [
        {
          name: 'customSetting'
          metricCategories: [
            {
              category: 'AllMetrics'
            }
          ]
          eventHubName: diagnosticDependencies.outputs.eventHubNamespaceEventHubName
          eventHubAuthorizationRuleResourceId: diagnosticDependencies.outputs.eventHubAuthorizationRuleId
          storageAccountResourceId: diagnosticDependencies.outputs.storageAccountResourceId
          workspaceResourceId: diagnosticDependencies.outputs.logAnalyticsWorkspaceResourceId
        }
      ]
      lock: {
        kind: 'CanNotDelete'
        name: 'myCustomLockName'
      }
      privateEndpoints: [
        {
          privateDnsZoneGroup: {
            privateDnsZoneGroupConfigs: [
              {
                privateDnsZoneResourceId: nestedDependencies.outputs.privateDNSZoneResourceId
              }
            ]
          }
          subnetResourceId: nestedDependencies.outputs.subnetResourceId
        }
      ]
      roleAssignments: [
        {
          roleDefinitionIdOrName: 'Owner'
          principalId: nestedDependencies.outputs.managedIdentityPrincipalId
          principalType: 'ServicePrincipal'
        }
        {
          roleDefinitionIdOrName: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
          principalId: nestedDependencies.outputs.managedIdentityPrincipalId
          principalType: 'ServicePrincipal'
        }
        {
          roleDefinitionIdOrName: subscriptionResourceId(
            'Microsoft.Authorization/roleDefinitions',
            'acdd72a7-3385-48ef-bd42-f606fba81ae7'
          )
          principalId: nestedDependencies.outputs.managedIdentityPrincipalId
          principalType: 'ServicePrincipal'
        }
      ]
      tags: {
        'hidden-title': 'This is visible in the resource name'
        Environment: 'Non-Prod'
        Role: 'DeploymentValidation'
      }
    }
  }
]
