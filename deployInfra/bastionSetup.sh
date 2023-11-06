function setup_environment_variables() {
    region=$(curl -sq http://169.254.169.254/latest/meta-data/placement/availability-zone/)
    region=${region: :-1}
    accountId=$(aws sts get-caller-identity | jq -r .Account)
    # CS_CID_LOWER=$(echo $CS_CID | cut -d '-' -f 1 | tr '[:upper:]' '[:lower:]')
    cd /etc/sudoers.d 
    echo "ssm-user ALL=(ALL) NOPASSWD:ALL" >> ssm-agent-users
}

function install_kubernetes_client_tools() {
    printf "\nInstall K8s Client Tools"
    mkdir -p /usr/local/bin/
    curl --retry 5 -o kubectl https://s3.us-west-2.amazonaws.com/amazon-eks/1.27.6/2023-10-17/bin/linux/amd64/kubectl
    chmod +x ./kubectl
    mv ./kubectl /usr/local/bin/
    mkdir -p /root/bin
    ln -s /usr/local/bin/kubectl /root/bin/
    ln -s /usr/local/bin/kubectl /opt/aws/bin

    # cat > /etc/profile.d/kubectl.sh <<EOF
    #!/bin/bash
    # source <(/usr/local/bin/kubectl completion bash)
    # EOF
    # chmod +x /etc/profile.d/kubectl.sh
    
    curl --retry 5 -o helm.tar.gz https://get.helm.sh/helm-v3.12.3-linux-amd64.tar.gz
    tar -xvf helm.tar.gz
    chmod +x ./linux-amd64/helm
    mv ./linux-amd64/helm /usr/local/bin/helm
    ln -s /usr/local/bin/helm /opt/aws/bin
    rm -rf ./linux-amd64/
# Install awscli v2
    curl -O "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
    unzip -o awscli-exe-linux-x86_64.zip
    sudo ./aws/install
    rm awscli-exe-linux-x86_64.zip
    mv /bin/aws /bin/aws.v1
    ln -s /usr/local/aws-cli/v2/current/dist/aws /bin/aws
}

function setup_kubeconfig() {

    printf "\nKube Config:\n"
    
    aws eks update-kubeconfig --name fcs-lab-EKS-cluster --region ${region}

  # AWS Load Balancer Controller install script
    cat >lbc-deploy.sh <<EOF
    helm repo add eks https://aws.github.io/eks-charts
    helm install aws-load-balancer-controller eks/aws-load-balancer-controller -n kube-system --set clusterName=fcs-lab-EKS-cluster --set serviceAccount.create=false --set serviceAccount.name=aws-load-balancer-controller
    
EOF

    # Add SSM Config for ssm-user
    /sbin/useradd -d /home/ssm-user -u 1001 -s /bin/bash -m --user-group ssm-user
    mkdir -p /home/ssm-user/.kube/
    cp ~/.kube/config /home/ssm-user/.kube/config
    cp lbc-deploy.sh /home/ssm-user/
    chown -R ssm-user:ssm-user /home/ssm-user/
    chmod -R og-rwx /home/ssm-user/.kube
    chmod +x /home/ssm-user/lbc-deploy.sh

}

function setup_nodesensor_config(){
    cat >/tmp/node_sensor.yaml <<EOF
apiVersion: falcon.crowdstrike.com/v1alpha1
kind: FalconNodeSensor
metadata:
  name: falcon-node-sensor
spec:
  falcon_api:
    client_id: <REPLACE WITH CS_API_CLIENT_ID>
    client_secret: <REPLACE WITH CS_API_CLIENT_SECRET>
    cloud_region: autodiscover
  node: {}
  falcon:
    tags: 
    - fcs-lab
EOF
    # To install Node Sensor, run the following command:
    # kubectl create -f /tmp/node_sensor.yaml

    cp /tmp/node_sensor.yaml /home/ssm-user/ 
    chown -R ssm-user:ssm-user /home/ssm-user/
    chmod og-rwx /home/ssm-user/node_sensor.yaml
}

setup_environment_variables
install_kubernetes_client_tools
setup_kubeconfig
setup_nodesensor_config