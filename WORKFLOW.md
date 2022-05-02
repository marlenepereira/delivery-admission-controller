# Testing Infrastructure: GitHub + Prow + Kubernetes
Steps:
1. Initial setup: Follow the instructions in the [/test-infra/config/README.md](./test-infra/config/README.md) to setup a local development for
testing CI workflows.
2. Install the Delivery Admission controller by following instructions [here](./README.md).

## Tests
### Passing
1. In a branch, update the name of the resource in the `good-request.yaml` file, [here](./config/samples/good_request.yaml).
2. Create a pull request.

Checks should pass.

### Failing
1. In a branch, update the name of the resource in the `bad-request.yaml` file, [here](./config/samples/bad_request.yaml).
2. Create a pull request.

Checks should fail.
