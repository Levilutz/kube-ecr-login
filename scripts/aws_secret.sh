#!/usr/bin/bash

set -e

if [ $# -ne 4 ]; then
    printf "Needs 4 arguments:\n"
    printf "\t- AWS_ACCESS_KEY_ID\n"
    printf "\t- AWS_SECRET_ACCESS_KEY\n"
    printf "\t- AWS_DEFAULT_REGION\n"
    printf "\t- AWS_ECR_SERVER\n"
    exit 1
fi

echo "Trying to delete old secret, if it exists"
kubectl delete secret kube-ecr-login-aws || true

echo "Creating new secret"
kubectl create secret generic kube-ecr-login-aws \
    --from-literal="AWS_ACCESS_KEY_ID=$1" \
    --from-literal="AWS_SECRET_ACCESS_KEY=$2" \
    --from-literal="AWS_DEFAULT_REGION=$3" \
    --from-literal="AWS_ECR_SERVER=$4" \

echo "Done"
