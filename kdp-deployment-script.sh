### Variable list
# IPAddresses
AWS_VPC_CIDR='172.2.0.0/20'
AWS_PUBLIC_SUBNET_CIDR_01='172.2.0.0/24'
AWS_PUBLIC_SUBNET_CIDR_02='172.2.1.0/24'
AWS_PRIVATE_SUBNET_CIDR_01='172.2.2.0/24'
# EC2 AMI image
AWS_BASTION_AMI_ID=ami-0a2306ef347189603
AWS_AMI_ID=ami-02af65b2d1ebdfafc
# Name Tags
AWS_VPC_NAME=kdp-dev-vpc-01
AWS_KEY=kdp-dev-key-01
AWS_PUBLIC_SUBNET_NAME_01=kdp-dev-public-subnet-01
AWS_PUBLIC_SUBNET_NAME_02=kdp-dev-public-subnet-02
AWS_PRIVATE_SUBNET_NAME_01=kdp-dev-private-subnet-01
AWS_INTERNET_GATEWAY_NAME=kdp-dev-igw-01
AWS_PUBLIC_ROUTE_TABLE_NAME=kdp-dev-vpc-public-route-table
AWS_PRIVATE_ROUTE_TABLE_NAME=kdp-dev-vpc-private-route-table
AWS_DEFAULT_SECURITY_GROUP_NAME=kdp-dev-default-sg
AWS_BASTION_SECURITY_GROUP_NAME=kdp-dev-bastion-sg
AWS_DS_SECURITY_GROUP_NAME=kdp-dev-ds-sg
AWS_KCE_SECURITY_GROUP_NAME=kdp-dev-kce-sg
AWS_EC2_INSTANCE_BASTION_NAME=kdp-dev-bastion-01
AWS_EC2_INSTANCE_DS_NAME=kdp-dev-ds-01
AWS_EC2_INSTANCE_KCE_NAME=kdp-dev-kce-01
AWS_ELB_NAME=kdp-dev-elb-01

echo Starting deployment of resouces
echo

## Create a VPC
AWS_VPC_ID=$(aws ec2 create-vpc \
--cidr-block $AWS_VPC_CIDR \
--query 'Vpc.{VpcId:VpcId}' \
--output text)

## Add a tag to the VPC
aws ec2 create-tags \
--resources $AWS_VPC_ID \
--tags "Key=Name,Value=$AWS_VPC_NAME"

echo Created VPC

## Enable DNS hostname for your VPC
aws ec2 modify-vpc-attribute \
--vpc-id $AWS_VPC_ID \
--enable-dns-hostnames "{\"Value\":true}"

## Create a public subnet 01
AWS_PUBLIC_SUBNET_ID_01=$(aws ec2 create-subnet \
--vpc-id $AWS_VPC_ID --cidr-block $AWS_PUBLIC_SUBNET_CIDR_01 \
--availability-zone us-east-2a --query 'Subnet.{SubnetId:SubnetId}' \
--output text)

## Add a tags to public subnet 01
aws ec2 create-tags \
--resources $AWS_PUBLIC_SUBNET_ID_01 \
--tags "Key=Name,Value=$AWS_PUBLIC_SUBNET_NAME_01"

## Enable Auto-assign Public IP on Public 01
aws ec2 modify-subnet-attribute \
--subnet-id $AWS_PUBLIC_SUBNET_ID_01 \
--map-public-ip-on-launch

## Create a public subnet 02
AWS_PUBLIC_SUBNET_ID_02=$(aws ec2 create-subnet \
--vpc-id $AWS_VPC_ID --cidr-block $AWS_PUBLIC_SUBNET_CIDR_02 \
--availability-zone us-east-2b --query 'Subnet.{SubnetId:SubnetId}' \
--output text)

## Add a tags to public subnet 02
aws ec2 create-tags \
--resources $AWS_PUBLIC_SUBNET_ID_02 \
--tags "Key=Name,Value=$AWS_PUBLIC_SUBNET_NAME_02"

## Enable Auto-assign Public IP on Public Subnet 02
aws ec2 modify-subnet-attribute \
--subnet-id $AWS_PUBLIC_SUBNET_ID_02 \
--map-public-ip-on-launch

## Create an Internet Gateway
AWS_INTERNET_GATEWAY_ID=$(aws ec2 create-internet-gateway \
--query 'InternetGateway.{InternetGatewayId:InternetGatewayId}' \
--output text)

## Add a tag to the Internet-Gateway
aws ec2 create-tags \
--resources $AWS_INTERNET_GATEWAY_ID \
--tags "Key=Name,Value=$AWS_INTERNET_GATEWAY_NAME"

## Attach Internet gateway to your VPC
aws ec2 attach-internet-gateway \
--vpc-id $AWS_VPC_ID \
--internet-gateway-id $AWS_INTERNET_GATEWAY_ID

## Create a route table
AWS_PUBLIC_ROUTE_TABLE_ID=$(aws ec2 create-route-table \
--vpc-id $AWS_VPC_ID \
--query 'RouteTable.{RouteTableId:RouteTableId}' \
--output text )

## Add a tag to the public route table
aws ec2 create-tags \
--resources $AWS_PUBLIC_ROUTE_TABLE_ID \
--tags "Key=Name,Value=$AWS_PUBLIC_ROUTE_TABLE_NAME"

## Create route to Internet Gateway
aws ec2 create-route \
--route-table-id $AWS_PUBLIC_ROUTE_TABLE_ID \
--destination-cidr-block 0.0.0.0/0 \
--gateway-id $AWS_INTERNET_GATEWAY_ID

## Associate the public subnet with route table
AWS_PUBLIC_ROUTE_TABLE_ASSOID=$(aws ec2 associate-route-table  \
--subnet-id $AWS_PUBLIC_SUBNET_ID_01 \
--route-table-id $AWS_PUBLIC_ROUTE_TABLE_ID \
--output text)

AWS_PUBLIC_ROUTE_TABLE_ASSOID=$(aws ec2 associate-route-table  \
--subnet-id $AWS_PUBLIC_SUBNET_ID_02 \
--route-table-id $AWS_PUBLIC_ROUTE_TABLE_ID \
--output text)

## Create a private subnet
AWS_PRIVATE_SUBNET_ID_01=$(aws ec2 create-subnet \
--vpc-id $AWS_VPC_ID --cidr-block $AWS_PRIVATE_SUBNET_CIDR_01 \
--availability-zone us-east-2a --query 'Subnet.{SubnetId:SubnetId}' \
--output text)

## Add a tags to private subnet
aws ec2 create-tags \
--resources $AWS_PRIVATE_SUBNET_ID_01 \
--tags "Key=Name,Value=$AWS_PRIVATE_SUBNET_NAME_01"

## Create a route table
AWS_PRIVATE_ROUTE_TABLE_ID=$(aws ec2 create-route-table \
--vpc-id $AWS_VPC_ID \
--query 'RouteTable.{RouteTableId:RouteTableId}' \
--output text )

## Add a tag to the private route table
aws ec2 create-tags \
--resources $AWS_PRIVATE_ROUTE_TABLE_ID \
--tags "Key=Name,Value=$AWS_PRIVATE_ROUTE_TABLE_NAME"

## Associate the private subnet with route table
AWS_PRIVATE_ROUTE_TABLE_ASSOID=$(aws ec2 associate-route-table  \
--subnet-id $AWS_PRIVATE_SUBNET_ID_01 \
--route-table-id $AWS_PRIVATE_ROUTE_TABLE_ID \
--output text)

## Create a security group for Bastion
aws ec2 create-security-group \
--vpc-id $AWS_VPC_ID \
--group-name $AWS_BASTION_SECURITY_GROUP_NAME \
--description 'Bastion security group'

## Get security group ID's
AWS_DEFAULT_SECURITY_GROUP_ID=$(aws ec2 describe-security-groups \
--filters "Name=vpc-id,Values=$AWS_VPC_ID" \
--query 'SecurityGroups[?GroupName == `default`].GroupId' \
--output text) &&
AWS_BASTION_SECURITY_GROUP_ID=$(aws ec2 describe-security-groups \
--filters "Name=vpc-id,Values=$AWS_VPC_ID" \
--query 'SecurityGroups[?GroupName == `kdp-dev-bastion-sg`].GroupId' \
--output text)

## Create security group ingress rules for Bastion Instance
aws ec2 authorize-security-group-ingress \
--group-id $AWS_BASTION_SECURITY_GROUP_ID \
--ip-permissions '[{"IpProtocol": "tcp", "FromPort": 22, "ToPort": 22, "IpRanges": [{"CidrIp": "0.0.0.0/0", "Description": "Allow SSH"}]}]' &&
aws ec2 authorize-security-group-ingress \
--group-id $AWS_BASTION_SECURITY_GROUP_ID \
--ip-permissions '[{"IpProtocol": "tcp", "FromPort": 80, "ToPort": 80, "IpRanges": [{"CidrIp": "0.0.0.0/0", "Description": "Allow HTTP"}]}]' &&
aws ec2 authorize-security-group-ingress \
--group-id $AWS_BASTION_SECURITY_GROUP_ID \
--ip-permissions '[{"IpProtocol": "tcp", "FromPort": 443, "ToPort": 443, "IpRanges": [{"CidrIp": "0.0.0.0/0", "Description": "Allow HTTPS"}]}]'

## Add a tags to Bastion security groups
aws ec2 create-tags \
--resources $AWS_BASTION_SECURITY_GROUP_ID \
--tags "Key=Name,Value=$AWS_BASTION_SECURITY_GROUP_NAME" &&
aws ec2 create-tags \
--resources $AWS_DEFAULT_SECURITY_GROUP_ID \
--tags "Key=Name,Value=$AWS_DEFAULT_SECURITY_GROUP_NAME"

## Create a security group for Docker and SuperSet
aws ec2 create-security-group \
--vpc-id $AWS_VPC_ID \
--group-name $AWS_DS_SECURITY_GROUP_NAME \
--description 'Docker and SuperSet security group'

AWS_DS_SECURITY_GROUP_ID=$(aws ec2 describe-security-groups \
--filters "Name=vpc-id,Values=$AWS_VPC_ID" \
--query 'SecurityGroups[?GroupName == `kdp-dev-ds-sg`].GroupId' \
--output text)

## Create security group ingress rules for Docker and SuperSet
aws ec2 authorize-security-group-ingress \
--group-id $AWS_DS_SECURITY_GROUP_ID \
--ip-permissions '[{"IpProtocol": "tcp", "FromPort": 22, "ToPort": 22, "IpRanges": [{"CidrIp": "0.0.0.0/0", "Description": "Allow SSH"}]}]' &&
aws ec2 authorize-security-group-ingress \
--group-id $AWS_DS_SECURITY_GROUP_ID \
--ip-permissions '[{"IpProtocol": "tcp", "FromPort": 80, "ToPort": 80, "IpRanges": [{"CidrIp": "0.0.0.0/0", "Description": "Allow HTTP"}]}]'

## Add a tags to Doceker and SuperSet security groups
aws ec2 create-tags \
--resources $AWS_DS_SECURITY_GROUP_ID \
--tags "Key=Name,Value=$AWS_DS_SECURITY_GROUP_NAME"

## Create a security group for Kafka, Cassandra and Elastic Search
aws ec2 create-security-group \
--vpc-id $AWS_VPC_ID \
--group-name $AWS_KCE_SECURITY_GROUP_NAME \
--description 'Kafka Cassandra and SuperSet security group'

AWS_KCE_SECURITY_GROUP_ID=$(aws ec2 describe-security-groups \
--filters "Name=vpc-id,Values=$AWS_VPC_ID" \
--query 'SecurityGroups[?GroupName == `kdp-dev-kce-sg`].GroupId' \
--output text)

## Create security group ingress rules for Docker and SuperSet
aws ec2 authorize-security-group-ingress \
--group-id $AWS_KCE_SECURITY_GROUP_ID \
--ip-permissions '[{"IpProtocol": "tcp", "FromPort": 22, "ToPort": 22, "IpRanges": [{"CidrIp": "0.0.0.0/0", "Description": "Allow SSH"}]}]' &&
aws ec2 authorize-security-group-ingress \
--group-id $AWS_KCE_SECURITY_GROUP_ID \
--ip-permissions '[{"IpProtocol": "tcp", "FromPort": 80, "ToPort": 80, "IpRanges": [{"CidrIp": "0.0.0.0/0", "Description": "Allow HTTP"}]}]'

## Add a tags to Doceker and SuperSet security groups
aws ec2 create-tags \
--resources $AWS_KCE_SECURITY_GROUP_ID \
--tags "Key=Name,Value=$AWS_KCE_SECURITY_GROUP_NAME"

## Create a key-pair
aws ec2 create-key-pair \
--key-name $AWS_KEY \
--query 'KeyMaterial' \
--output text > EI-Dev-keypair.pem

## Create an EC2 instance for Bastion
AWS_EC2_INSTANCE_ID_BASTION=$(aws ec2 run-instances \
--image-id $AWS_BASTION_AMI_ID \
--instance-type t4g.nano \
--key-name $AWS_KEY \
--monitoring "Enabled=false" \
--security-group-ids $AWS_BASTION_SECURITY_GROUP_ID \
--subnet-id $AWS_PUBLIC_SUBNET_ID_01 \
--user-data file://bastion-nat.txt \
--query 'Instances[0].InstanceId' \
--output text)

echo Script will proceed after 60 seconds, please be Patient

sleep 60

aws ec2 modify-instance-attribute --instance-id $AWS_EC2_INSTANCE_ID_BASTION --no-source-dest-check

## Create route to Bastion NAT Instance for Private Subnets
aws ec2 create-route \
--route-table-id $AWS_PRIVATE_ROUTE_TABLE_ID \
--destination-cidr-block 0.0.0.0/0 \
--instance-id $AWS_EC2_INSTANCE_ID_BASTION

## Add a tag to the ec2 instance of Bastion
aws ec2 create-tags \
--resources $AWS_EC2_INSTANCE_ID_BASTION \
--tags "Key=Name,Value=$AWS_EC2_INSTANCE_BASTION_NAME"

## Create an EC2 instance for Docker and Superset
AWS_EC2_INSTANCE_ID_DS_01=$(aws ec2 run-instances \
--image-id $AWS_AMI_ID \
--instance-type t4g.micro \
--block-device-mappings file://mapping.json \
--key-name $AWS_KEY \
--monitoring "Enabled=false" \
--security-group-ids $AWS_DS_SECURITY_GROUP_ID \
--subnet-id $AWS_PRIVATE_SUBNET_ID_01 \
--user-data file://ds.txt \
--query 'Instances[0].InstanceId' \
--output text)

## Add a tag to the ec2 instance of docker and superset
aws ec2 create-tags \
--resources $AWS_EC2_INSTANCE_ID_DS_01 \
--tags "Key=Name,Value=$AWS_EC2_INSTANCE_DS_NAME"

## Create an EC2 instance for Kafka, Cassandra and ElasticSearch
AWS_EC2_INSTANCE_ID_KCE_01=$(aws ec2 run-instances \
--image-id $AWS_AMI_ID \
--instance-type t4g.2xlarge \
--block-device-mappings file://mapping.json \
--key-name $AWS_KEY \
--monitoring "Enabled=false" \
--security-group-ids $AWS_KCE_SECURITY_GROUP_ID \
--subnet-id $AWS_PRIVATE_SUBNET_ID_01 \
--user-data file://kce.txt \
--query 'Instances[0].InstanceId' \
--output text)

## Add a tag to the ec2 instance of docker and superset
aws ec2 create-tags \
--resources $AWS_EC2_INSTANCE_ID_KCE_01 \
--tags "Key=Name,Value=$AWS_EC2_INSTANCE_KCE_NAME"

echo Deployment complete
