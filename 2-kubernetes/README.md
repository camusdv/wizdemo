# Deploy

```sh
terraform init
terraform apply
```

# Post deployment manual updates

1. In EKS UI, change access to allow both ConfigMap and API access

2. Once cluster Kubeconfig is downloaded, edit the file and modify `apiVersion:` from:

```yaml
apiVersion: client.authentication.k8s.io/v1alpha1
```

to:

``` yaml
apiVersion: client.authentication.k8s.io/v1beta1
```

## Current issue 1

When call `kubectl --kubeconfig <config file> get nodes`, the following error is observed:

```
"error: exec plugin: invalid apiVersion "client.authentication.k8s.io/v1alpha1"
```

Solution:

1. Download awscli version 2:

```sh
# Download AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"

# Un-compress the archive
unzip awscliv2.zip

# Run the installer
sudo ./aws/install
```

2. Download kubeconfig again

```sh
aws eks update-kubeconfig --region ${AWS_REGION}  --name ${EKS_CLUSTER_NAME} --kubeconfig ${KUBECONFIG_PATH}
```

3. Modify kubeconfig entry, `apiVersion:` from:

```yaml
apiVersion: client.authentication.k8s.io/v1alpha1
```

to:

``` yaml
apiVersion: client.authentication.k8s.io/v1beta1
```

## Current issue 2

When call `kubectl --kubeconfig <config file> get nodes`, the following error is observed:

```
eks couldn't get current server API group list: Get "https://": getting credentials: decoding stdout: no kind "ExecCredential" is registered for version "client.authentication.k8s.io/
```

Solution:

1. Download awscli version 2:

```sh
# Download AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"

# Un-compress the archive
unzip awscliv2.zip

# Run the installer
sudo ./aws/install
```
