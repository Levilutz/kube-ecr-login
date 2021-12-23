kubectl delete cronjob kube-ecrlogin || true
kubectl delete serviceaccount kube-ecrlogin || true
kubectl delete clusterrole kube-ecrlogin || true
kubectl delete clusterrolebinding kube-ecrlogin || true
