#!/usr/bin/bash

set -e

echo "Creating working container"
container=$(buildah from docker://debian:bullseye)

echo "Downloading kubectl"
kube_latest=`curl -L -s https://dl.k8s.io/release/stable.txt`
curl -LO "https://dl.k8s.io/release/$kube_latest/bin/linux/amd64/kubectl"

echo "Adding kubectl to container"
buildah add $container kubectl /usr/local/bin/kubectl
buildah run $container chmod u+x /usr/local/bin/kubectl

echo "Downloading awscli"
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip

echo "Adding awscli to container"
buildah copy $container aws /aws
buildah run $container /aws/install

echo "Installing netcat on container"
buildah run $container apt-get update -y
buildah run $container apt-get install -y netcat
buildah run $container apt-get clean -y

echo "Copying entrypoint to container"
buildah copy $container main/src/entrypoint.sh /entrypoint.sh

echo "Configuring container"
buildah config --entrypoint "bash /entrypoint.sh" $container
buildah config --author "Levi Lutz (contact.levilutz@gmail.com)" $container

echo "Building container to image"
buildah commit $container kube-ecrlogin-main

echo "Cleaning up"
buildah rm $container
rm kubectl
rm awscliv2.zip
rm -r aws
