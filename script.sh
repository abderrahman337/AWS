#!/bin/bash
#--installing jq
sudo apt-get install jq -y

#--running the cloud formation stack for Cognito setup
aws_region="us-east-1"
aws_user_pool_name="MyUserPool"
aws_client_app_name="MyPoolClientApp"
aws cloudformation create-stack \
   --template-body file://cognito-setup.yaml \
   --stack-name CognitoSetup \
   --capabilities CAPABILITY_AUTO_EXPAND CAPABILITY_NAMED_IAM \
   --parameters \
     ParameterKey=UserPoolName,ParameterValue=$aws_user_pool_name \
     ParameterKey=UserPoolClientName,ParameterValue=$aws_client_app_name

#-- getting the output of cloud formation stack
status="start"

while [ "$status" != "CREATE_COMPLETE" ]
do
   aws cloudformation describe-stacks --stack-name CognitoSetup > output.json
   status=$(jq -r '.Stacks[].StackStatus' output.json)
   sleep 10
done

aws cloudformation describe-stacks --stack-name CognitoSetup > output.json

UserPoolClientId=$(jq -r '.Stacks[].Outputs[] | select(.OutputKey=="UserPoolClientId") | .OutputValue' output.json)
UserPoolId=$(jq -r '.Stacks[].Outputs[] | select(.OutputKey=="UserPoolId") | .OutputValue' output.json)
UserGitURL=$(jq -r '.Stacks[].Outputs[] | select(.OutputKey=="UserGitURL") | .OutputValue' output.json)
UserGitARN=$(jq -r '.Stacks[].Outputs[] | select(.OutputKey=="UserGitARN") | .OutputValue' output.json)
UserPoolARN=$(jq -r '.Stacks[].Outputs[] | select(.OutputKey=="UserPoolARN") | .OutputValue' output.json)

#--running the cloud formation stack for Backend setup
aws_redshift_cluster_ep="redshift-cluster-1.ceoxukbfhxkk.us-east-1.redshift.amazonaws.com:5439/dev"
aws_dbuser_name="awsuser"
aws_ddbtable_name="client_connections_a"
aws_wsep_param_name="REDSHIFT_WSS_ENDPOINT_a"
aws_rapiep_param_name="REDSHIFT_REST_API_ENDPOINT_a"
aws cloudformation create-stack \
   --template-body file://backend-setup.yaml \
   --stack-name BackendSetup \
   --capabilities CAPABILITY_AUTO_EXPAND CAPABILITY_NAMED_IAM CAPABILITY_IAM \
   --parameters \
     ParameterKey=RedshiftClusterEndpoint,ParameterValue=$aws_redshift_cluster_ep \
     ParameterKey=DbUsername,ParameterValue=$aws_dbuser_name \
     ParameterKey=DDBTableName,ParameterValue=$aws_ddbtable_name \
     ParameterKey=WebSocketEndpointSSMParameterName,ParameterValue=$aws_wsep_param_name \
     ParameterKey=RestApiEndpointSSMParameterName,ParameterValue=$aws_rapiep_param_name \
     ParameterKey=UserPoolARN,ParameterValue=$UserPoolARN

#-- getting the output of cloud formation stack
status="start"

while [ "$status" != "CREATE_COMPLETE" ]
do
   aws cloudformation describe-stacks --stack-name BackendSetup > output1.json
   status=$(jq -r '.Stacks[].StackStatus' output1.json)
   sleep 10
done

aws cloudformation describe-stacks --stack-name BackendSetup > output1.json

RedshiftDataApiWebSocketEndpoint=$(jq -r '.Stacks[].Outputs[] | select(.OutputKey=="RedshiftDataApiWebSocketEndpoint") | .OutputValue' output1.json)
RedshiftDataApiRestApiEndpoint=$(jq -r '.Stacks[].Outputs[] | select(.OutputKey=="RedshiftDataApiRestApiEndpoint") | .OutputValue' output1.json)

echo $UserPoolClientId
echo $UserPoolId
echo $UserGitURL
echo $UserGitARN
echo $UserPoolARN
echo $RedshiftDataApiWebSocketEndpoint
echo $RedshiftDataApiRestApiEndpoint

#-- Clone the repository using HTTPS and a personal access token
git clone https://github.com/AziizeLbaibi/DemoApp.git || echo "DemoApp directory already exists. Skipping clone."

# Move into the cloned directory
cp -R Src_directory/* DemoApp
cd DemoApp/js
search1="userPoolIdValue"
search2="userPoolClientIdValue"
search3="userRegionValue"
search4="userWebSURL"
search5="userRestURL"
sed -i "s|$search1|$UserPoolId|g" config.js
sed -i "s|$search2|$UserPoolClientId|g" config.js
sed -i "s|$search3|$aws_region|g" config.js
sed -i "s|$search4|$RedshiftDataApiWebSocketEndpoint|g" config.js
sed -i "s|$search5|$RedshiftDataApiRestApiEndpoint|g" config.js
cd ..
git add .
git commit -m 'new'
git push
cd ..

#-- Check if webapp-setup.yaml exists before proceeding
if [ -f "webapp-setup.yaml" ]; then
    aws cloudformation create-stack \
       --template-body file://webapp-setup.yaml \
       --stack-name WebappSetup \
       --capabilities CAPABILITY_AUTO_EXPAND CAPABILITY_NAMED_IAM \
       --parameters \
         ParameterKey=UserGitURL,ParameterValue=$UserGitURL \
         ParameterKey=UserGitARN,ParameterValue=$UserGitARN
else
    echo "webapp-setup.yaml file not found, skipping the WebappSetup stack creation."
fi

echo "Task Completed"
