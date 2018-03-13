# Lab-Setup.ps1

# Import VPC helper functions
. ./vpc-functions.ps1

#Import AWS credentials
. ./credentials.ps1
#The credentials file should contain the following two variables:
# $AWSAccessKey="" # Your access key
# $AWSSecretKey="" # Your secret key

# Set AWS credentials
$AWSProfileName="aws-networking-deep-dive-route-53-dns"

# Set region-specific settings
$AWSRegionA = "us-east-1"
$amiRegionA = "ami-48351d32" #aws-elasticbeanstalk-amzn-2017.09.1.x86_64-ecs-hvm-201801192255
$AWSRegionB = "us-west-1"
$amiRegionB = "ami-f7383a97" #aws-elasticbeanstalk-amzn-2017.09.1.x86_64-ecs-hvm-201801180451

# Set your IP subnet for SSH access
$myIP = "24.96.154.168/29"

# Set the name of your SSH keypair
$keyname = "ccnetkeypair"

# Set instance type
$itype = "t2.nano"

# Set AWS credentials and store them
Set-AWSCredential -AccessKey $AWSAccessKey -SecretKey $AWSSecretKey -StoreAs $AWSProfileName

# Load the credentials for this session
Set-AWSCredential -ProfileName $AWSProfileName

###
### Region A setup

    # Set the default region
    Set-DefaultAWSRegion -Region $AWSRegionA
    $currentregion = (Get-DefaultAWSRegion).region

    # Test functionality
    if ((Get-EC2Vpc).count -ge 1) { Write-Host Connectivity to AWS region $currentregion established! }

    # Create webapp-vpc
    $vpc = Create-VPC -vpcCidr "172.3.0.0/16" -vpcName "r53-lab-vpc"

    # Create subnet
    $subnet = Create-Subnet -vpc $vpc -zone "us-east-1a" -name "r53-lab-1a" -IPv4Cidr "172.3.0.0/24" -IPv6Prefix "00"

    # Create internet gateway
    $igw = Create-InternetGateway -vpc $vpc -name "r53-lab-igw"

    # Create route table and associate with subnet
    $rt = Create-RouteTable -vpc $vpc -name "r53-lab-rt"
    Register-EC2RouteTable -RouteTableId $rt.RouteTableId -SubnetId $subnet.SubnetId

    # Add default routes
    New-EC2Route -DestinationCidrBlock "0.0.0.0/0" -GatewayId $igw.InternetGatewayId -RouteTableId $rt.RouteTableId

    # Create security groups
    $sg = New-EC2SecurityGroup -VpcId $vpc.VpcId -GroupName "r53-lab-sg" -GroupDescription "r53-lab-sg"

    # Create IPpermissions for public http and https
    $httpip = new-object Amazon.EC2.Model.IpPermission
    $httpip.IpProtocol = "tcp"
    $httpip.FromPort = 80
    $httpip.ToPort = 80
    $httpip.IpRanges.Add("0.0.0.0/0")

    $httpsip = new-object Amazon.EC2.Model.IpPermission
    $httpsip.IpProtocol = "tcp"
    $httpsip.FromPort = 443
    $httpsip.ToPort = 443
    $httpsip.IpRanges.Add("0.0.0.0/0")

    $sship = new-object Amazon.EC2.Model.IpPermission
    $sship.IpProtocol = "tcp"
    $sship.FromPort = 22
    $sship.ToPort = 22
    $sship.IpRanges.Add($myIP)

    Grant-EC2SecurityGroupIngress -GroupId $sg -IpPermissions @( $httpip, $httpsip, $sship )

    ##
    ## Create web1-east instance

        # Create elastic network interface
        $primary = "172.3.0.10"
        $desc = "web1-east eth0"
        $eni = New-EC2NetworkInterface -SubnetId $subnet.SubnetId -Description $desc -PrivateIPAddress $primary -Group $sg

        # Allocate elastic IP
        $eip = New-EC2Address

        # Associate elastic IP with web1-east eth0 ENI
        Register-EC2Address -AllocationId $eip.AllocationId -NetworkInterfaceId $eni.NetworkInterfaceId

        # Create web1-east instance
        $eth0 = new-object Amazon.EC2.Model.InstanceNetworkInterfaceSpecification
        $eth0.NetworkInterfaceId = $eni.NetworkInterfaceId
        $eth0.DeviceIndex = 0
        $eth0.DeleteOnTermination = $false
        $web1 = New-EC2Instance -ImageId $amiRegionA -KeyName $keyname -InstanceType $itype -NetworkInterface $eth0
        New-NameTag -name "web1-east" -resourceID $web1.Instances.InstanceId

    ##
    ## Create web2-east instance

        Create elastic network interface
        $primary = "172.3.0.20"
        $desc = "web2-east eth0"
        $eni = New-EC2NetworkInterface -SubnetId $subnet.SubnetId -Description $desc -PrivateIPAddress $primary -Group $sg

        # Allocate elastic IP
        $eip = New-EC2Address

        # Associate elastic IP with web1-east eth0 ENI
        Register-EC2Address -AllocationId $eip.AllocationId -NetworkInterfaceId $eni.NetworkInterfaceId

        # Create web1-east instance
        $eth0 = new-object Amazon.EC2.Model.InstanceNetworkInterfaceSpecification
        $eth0.NetworkInterfaceId = $eni.NetworkInterfaceId
        $eth0.DeviceIndex = 0
        $eth0.DeleteOnTermination = $false
        $web2 = New-EC2Instance -ImageId $amiRegionA -KeyName $keyname -InstanceType $itype -NetworkInterface $eth0
        New-NameTag -name "web2-east" -resourceID $web2.Instances.InstanceId


###
### Region B setup

    # Set the default region
    Set-DefaultAWSRegion -Region $AWSRegionB
    $currentregion = (Get-DefaultAWSRegion).region

    # Test functionality
    if ((Get-EC2Vpc).count -ge 1) { Write-Host Connectivity to AWS region $currentregion established! }

    # Create webapp-vpc
    $vpc = Create-VPC -vpcCidr "172.9.0.0/16" -vpcName "r53-lab-vpc"

    # Create subnet
    $subnet = Create-Subnet -vpc $vpc -zone "us-west-1a" -name "r53-lab-1a" -IPv4Cidr "172.9.0.0/24" -IPv6Prefix "00"

    # Create internet gateway
    $igw = Create-InternetGateway -vpc $vpc -name "r53-lab-igw"

    # Create route table and associate with subnet
    $rt = Create-RouteTable -vpc $vpc -name "r53-lab-rt"
    Register-EC2RouteTable -RouteTableId $rt.RouteTableId -SubnetId $subnet.SubnetId

    # Add default routes
    New-EC2Route -DestinationCidrBlock "0.0.0.0/0" -GatewayId $igw.InternetGatewayId -RouteTableId $rt.RouteTableId

    # Create security groups
    $sg = New-EC2SecurityGroup -VpcId $vpc.VpcId -GroupName "r53-lab-sg" -GroupDescription "r53-lab-sg"

    # Create IPpermissions for public http and https
    $httpip = new-object Amazon.EC2.Model.IpPermission
    $httpip.IpProtocol = "tcp"
    $httpip.FromPort = 80
    $httpip.ToPort = 80
    $httpip.IpRanges.Add("0.0.0.0/0")

    $httpsip = new-object Amazon.EC2.Model.IpPermission
    $httpsip.IpProtocol = "tcp"
    $httpsip.FromPort = 443
    $httpsip.ToPort = 443
    $httpsip.IpRanges.Add("0.0.0.0/0")

    $sship = new-object Amazon.EC2.Model.IpPermission
    $sship.IpProtocol = "tcp"
    $sship.FromPort = 22
    $sship.ToPort = 22
    $sship.IpRanges.Add($myIP)

    Grant-EC2SecurityGroupIngress -GroupId $sg -IpPermissions @( $httpip, $httpsip, $sship )

    ##
    ## Create web1-west instance

        # Create elastic network interface
        $primary = "172.9.0.10"
        $desc = "web1-west eth0"
        $eni = New-EC2NetworkInterface -SubnetId $subnet.SubnetId -Description $desc -PrivateIPAddress $primary -Group $sg

        # Allocate elastic IP
        $eip = New-EC2Address

        # Associate elastic IP with web1-east eth0 ENI
        Register-EC2Address -AllocationId $eip.AllocationId -NetworkInterfaceId $eni.NetworkInterfaceId

        # Create web1-east instance
        $eth0 = new-object Amazon.EC2.Model.InstanceNetworkInterfaceSpecification
        $eth0.NetworkInterfaceId = $eni.NetworkInterfaceId
        $eth0.DeviceIndex = 0
        $eth0.DeleteOnTermination = $false
        $web1 = New-EC2Instance -ImageId $amiRegionB -KeyName $keyname -InstanceType $itype -NetworkInterface $eth0
        New-NameTag -name "web1-west" -resourceID $web1.Instances.InstanceId

    ##
    ## Create web2-west instance

        # Create elastic network interface
        $primary = "172.9.0.20"
        $desc = "web2-west eth0"
        $eni = New-EC2NetworkInterface -SubnetId $subnet.SubnetId -Description $desc -PrivateIPAddress $primary -Group $sg

        # Allocate elastic IP
        $eip = New-EC2Address

        # Associate elastic IP with web1-east eth0 ENI
        Register-EC2Address -AllocationId $eip.AllocationId -NetworkInterfaceId $eni.NetworkInterfaceId

        # Create web1-east instance
        $eth0 = new-object Amazon.EC2.Model.InstanceNetworkInterfaceSpecification
        $eth0.NetworkInterfaceId = $eni.NetworkInterfaceId
        $eth0.DeviceIndex = 0
        $eth0.DeleteOnTermination = $false
        $web2 = New-EC2Instance -ImageId $amiRegionB -KeyName $keyname -InstanceType $itype -NetworkInterface $eth0
        New-NameTag -name "web2-west" -resourceID $web2.Instances.InstanceId