# Delivery Admission Controller 2
Simple Kubernetes admission controller using [Kubebuilder][01].

## Install it locally
Assuming you have [kubectl][00] already installed.
```shell
# Install kind if you haven't already.
brew install kind

# Create a kind cluster. This command will create a kind cluster with a control plane and a worker node.
# It will also download the latest CertManager manifests and apply it to the cluster. You need Cert Manager to
# inject the certificate the API server uses to authenticate to your webhook server.
make local-cluster-setup

# Switch context to the kind cluster.
kubectl config set-context kind-local

# Install the CRDs into the cluster.
make install

# This command will build an new image of the admission controller and load it into the local cluster.
# Then it will generate the manifests in ./manifests and apply it to the local cluster.
make apply

# Run this command to uninstall the admission controller.
make undeploy

# Run this command to uninstall CertManager and delete the local KinD cluster.
make local-cluster-tear-down
```

[00]: https://kubernetes.io/docs/tasks/tools/
[01]: https://github.com/kubernetes-sigs/kubebuilder
