# Setting up Kubernetes environment using AWS

The current repository is a prove of concept for setting up an environment for
`Kubernetes`, based on `AWS` infrastructure. We will deploy an empty `Django` project.  

## AWS infrastructure

This guide assumes you already have an AWS account.

Following the guide, you will create an AWS EKS cluster, an AWS ECR repository, an AWS LoadBalancer and a few more resources.

## Setting UP local environment

The current guide assumes the developer uses Ubuntu 18 on its machine.

### Installing dependencies
```bash
sudo apt-get update
sudo apt-get install -y python-pip curl apt-transport-https docker.io
sudo usermod -aG docker `whoami`
# reboot
```
At this point it is good to restart you system so all sessions are aware of this update.
```sudo su - `whoami` ``` might be an alternative for the reboot, but you will have to do this for all sessions that will use docker until you restart.  

### Creating local aws cli configuration profile

If you already have aws cli configured with your account you can skip this step.

```bash
sudo -H pip install awscli
AWS_PROFILE=awskube
aws configure --profile ${AWS_PROFILE}
export AWS_PROFILE
```

More details on how to configure your AWS CLI [here](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html)

Make sure you run the **AWS_PROFILE** export each time you one a new terminal.

### Get this repo source code
```bash
git clone git@github.com:bodo-ata/djakube.git
```

### Creating the EKS cluster and its dependencies
To ease up things I've merged two sample Cloud Formation templates for EKS Cluster
VPC [sample1](https://amazon-eks.s3-us-west-2.amazonaws.com/cloudformation/2018-12-10/amazon-eks-vpc-sample.yaml)
and for Worker nodes [sample2](https://amazon-eks.s3-us-west-2.amazonaws.com/cloudformation/2018-12-10/amazon-eks-nodegroup.yaml)
and a few more resources to include all things needed).

This setup will generate about $0.07/h extra costs. To clean up the setup, just remove all docker images from the ECR and delete the Cloud Formation stack at the end.

Check [AWS EKS optimized ami page](https://docs.aws.amazon.com/eks/latest/userguide/eks-optimized-ami.html)
and identify the ami for your region (version 1.11).

From AWS EC2 Console go to Network & Security - Key Pairs and identify the name of the key pair you want to use for the workers (create one if none). 

Feel free to update the stack name as you like.
```bash
STACK_NAME="kube-poc"
AMI_ID="ami-xxxxxx"
KEY_NAME="key-pair-name"
aws cloudformation create-stack \
    --capabilities CAPABILITY_NAMED_IAM CAPABILITY_IAM \
    --stack-name ${STACK_NAME} \
    --parameters ParameterKey=NodeImageId,ParameterValue=${AMI_ID},UsePreviousValue=false \
                 ParameterKey=KeyName,ParameterValue=${KEY_NAME},UsePreviousValue=false \
    --template-body "$(< eks-cft-sample.yaml)"
```
Alternatively you could create the stack from AWS Cloud Formation Console by providing the eks-cft-sample.yaml.
You can also check the new stack state from AWS Cloud Formation Console as it will take some time until it sets up everything (10-15 minutes).

### Downloading aws-iam-authenticator
```bash
mkdir ~/bin
cd ~/bin
curl -o aws-iam-authenticator https://amazon-eks.s3-us-west-2.amazonaws.com/1.11.5/2018-12-06/bin/linux/amd64/aws-iam-authenticator
chmod u+x aws-iam-authenticator
echo 'export PATH=$HOME/bin:$PATH' >> ~/.bashrc
export PATH=$HOME/bin:$PATH
```

Link to the binary might get updated, please check [page](https://docs.aws.amazon.com/eks/latest/userguide/getting-started.html) for latest binaries.

### Installing kubectl
```bash
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubectl
```

Optionally you can enable kubectl auto complete
```bash
echo "source <(kubectl completion bash)" >> ~/.bashrc
```

### Configuring kubectl to use AWS EKS
Please first wait for Cloud Formation stack to create the cluster (reach active state), and then you can continue with this step.
```bash
CLUSTER_NAME=${STACK_NAME}
aws eks update-kubeconfig --name ${CLUSTER_NAME} 
```
Note: EKS cluster name matches the CF stack name.

### Test your setup
```bash
export AWS_PROFILE="awskube"
kubectl get svc
```

### Enable worker nodes to join the cluster
We need to find the ARN of the Worker Node Instance Role, update the configuration and then apply it. 
```bash
# STACK_NAME="kube-poc"
curl -O https://amazon-eks.s3-us-west-2.amazonaws.com/cloudformation/2018-12-10/aws-auth-cm.yaml
WORKER_INSTANCE_ROLE_ARN=`aws iam get-role --role-name ${STACK_NAME}-workerNodeInstanceRole|grep "Arn"|cut -d '"' -f 4`
sed -i "s|rolearn\: .*|rolearn\: ${WORKER_INSTANCE_ROLE_ARN}|" aws-auth-cm.yaml
kubectl apply -f aws-auth-cm.yaml
kubectl get nodes --watch
```
You might need to wait for the Cloud Formation stack to be fully created and worker nodes started.

## Deploying the app

### Docker Image 
Follow the push commands steps for the newly created AWS ECR (visible from AWS ECR console -> view push commands), or identify your AWS account id and region and run the next script. 
```bash
AWS_REGION="zz-yyyy-x"
AWS_ACCOUNT_ID="xxxxxxxxxxxx"
$(aws ecr get-login --no-include-email)
docker build -t ${STACK_NAME}-djakube .
docker tag ${STACK_NAME}-djakube:latest ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${STACK_NAME}-djakube:latest
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${STACK_NAME}-djakube:latest
```

### Setting the ReplicationController and Service
```bash
kubectl apply -f djakube-controller.json 
kubectl apply -f djakube-service.json 
```

### Check that is working
```bash
kubectl get pods
kubectl get service djakube
```
If pods are running, you should be able to access the service using the service EXTERNAL-IP in a browser.

## Have fun experimenting forward

Enjoy!

## Feedback is welcome

- Have issue following the guide?
- Would you like more content to it?
- Other suggestions you want to make?

Just let me know by creating issues to this repo.