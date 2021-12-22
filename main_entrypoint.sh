set -e

echo "Validating connected to cluster"
kubectl auth can-i '' ''
if [ $? -ne 0 ]; then echo "Failed to connect"; exit 1; fi

echo "Getting ECR password from AWS"
ecr_pass=$(aws ecr get-login-password --region=us-east-1)

echo "Trying to delete old secret, if it exists"
kubectl delete secret regcred || true

echo "Creating new secret"
kubectl create secret docker-registry regcred --docker-server=$AWS_ECR_SERVER --docker-username=AWS --docker-password=$ecr_pass
