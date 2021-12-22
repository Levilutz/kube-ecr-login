set -e

echo "Creating working container"
container=$(buildah from docker://alpine:3.15)

echo "Downloading kubectl"
kube_latest=`curl -L -s https://dl.k8s.io/release/stable.txt`
curl -LO "https://dl.k8s.io/release/$kube_latest/bin/linux/amd64/kubectl"

echo "Adding kubectl to container"
buildah add $container kubectl /usr/local/bin/kubectl
buildah run $container chmod u+x /usr/local/bin/kubectl

echo "Configuring container"
buildah config --cmd "kubectl proxy --port 8080" $container
buildah config --port 8001/tcp $container
buildah config --author "Levi Lutz (contact.levilutz@gmail.com)" $container

echo "Building container to image"
buildah commit $container kube-ecrlogin-sidecar
