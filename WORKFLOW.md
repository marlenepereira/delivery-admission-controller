# Testing Infrastructure: GitHub + Prow + Kubernetes
Steps:
1. Create a KinD cluster and install Prow: Follow the instructions in the [/test-infra/config/README.md](./test-infra/config/README.md).
2. Install the Delivery Admission controller by following instructions [here](./README.md).
3. Deploy the Kubernetes resources, i.e. Role, Rolebinding, etc., required by the `kube-dry-run` job.
```shell
kubectl apply -f test-infra/test/kube-dry-run.yaml
```
4. Build the docker image defined in [test-infra/test/Dockerfile](./test-infra/test/Dockerfile)
```shell
docker build -t kube-dry-run:latest ./test-infra/test
```
and load the `kube-dry-run` image into the cluster
```shell
kind load docker-image kube-dry-run:latest --name local
```

## Tests
### Passing
1. In a branch, update the name of the resource in the `bad-request.yaml` file, [here](./config/samples/good_request.yaml).
2. Create a pull request.

The `kube-dry-run` checks should fail as the `kube-dry-run` test always applies a static configuration file mounted in the
test-pods, [see](./test-infra/test/kube-dry-run.yaml).
