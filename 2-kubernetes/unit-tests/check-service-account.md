# Steps:

1. See Assigned Service Account:

```sh
kubectl get pods -n tasky --output=jsonpath='{.items[*].spec.serviceAccountName}'
```
2. Check Assigned Role

```sh
kubectl get clusterrolebinding -o json | jq -r '.items[] | select(.roleRef.name=="cluster-admin") | .subjects[] | select(.kind=="ServiceAccount" and .name=="tasky-service-account" and .namespace=="tasky")'
```

3. Call some cluster admin commands (need to add kubectl binary in the pod)

```sh
kubectl exec -it tasky-deployment-58cd4cbcf-sczb9 -n tasky -- /bin/sh -c 'kubectl get namespaces'

kubectl exec -it tasky-deployment-58cd4cbcf-sczb9 -n tasky -- /bin/sh -c 'kubectl get nodes'
```
