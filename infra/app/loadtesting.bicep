param loadTestName string = ''
param location string = resourceGroup().location
param description string = 'Load test for my application'
param tags object = {}

module loadTest 'br/public:avm/res/load-test-service/load-test:0.4.1' = {
  name: 'loadTestDeployment'
  params: {
    // Required parameters
    name: loadTestName
    // Non-required parameters
    loadTestDescription: description
    location: location
    tags: tags
  }
}


output loadTestName string = loadTest.outputs.name
