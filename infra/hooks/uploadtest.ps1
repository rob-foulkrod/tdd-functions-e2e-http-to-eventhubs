# Read variables from environment variables
$resourceGroupName = $env:RESOURCE_GROUP
$loadTestResourceName = $env:LOADTESTING_NAME
$jmxFilePath = './loadtest/httppost.jmx'
$subnetId = $env:LOAD_SUBNET_ID
$functionAppName = $env:AZURE_FUNCTION_NAME

# Create a load test with subnet details and environment variable for Function App name
az load test create --resource-group $resourceGroupName --name $loadTestResourceName --test-id e2e-demo-test --test-plan $jmxFilePath --test-type JMX --autostop-error-rate 10.0 --subnet-id $subnetId --env FUNCTION_APP_NAME=$functionAppName
