kubectl delete cronjob kube-ecr-login || true
kubectl delete serviceaccount kube-ecr-login || true
kubectl delete clusterrole kube-ecr-login || true
kubectl delete clusterrolebinding kube-ecr-login || true
