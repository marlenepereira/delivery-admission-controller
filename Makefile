
# Image URL to use all building/pushing image targets
IMG ?= delivery-controller:latest
# Produce CRDs that work back to Kubernetes 1.11 (no version conversion)
CRD_OPTIONS ?= "crd:trivialVersions=true,preserveUnknownFields=false"

# Get the currently used golang install path (in GOPATH/bin, unless GOBIN is set)
ifeq (,$(shell go env GOBIN))
GOBIN=$(shell go env GOPATH)/bin
else
GOBIN=$(shell go env GOBIN)
endif

# Setting SHELL to bash allows bash commands to be executed by recipes.
# This is a requirement for 'setup-envtest.sh' in the test target.
# Options are set to exit when a recipe line exits non-zero or a piped command fails.
SHELL = /usr/bin/env bash -o pipefail
.SHELLFLAGS = -ec

all: build

##@ General

# The help target prints out all targets with their descriptions organized
# beneath their categories. The categories are represented by '##@' and the
# target descriptions by '##'. The awk commands is responsible for reading the
# entire set of makefiles included in this invocation, looking for lines of the
# file as xyz: ## something, and then pretty-format the target and help. Then,
# if there's a line with ##@ something, that gets pretty-printed as a category.
# More info on the usage of ANSI control characters for terminal formatting:
# https://en.wikipedia.org/wiki/ANSI_escape_code#SGR_parameters
# More info on the awk command:
# http://linuxcommand.org/lc3_adv_awk.php

help: ## Display this help.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Development

manifests: controller-gen ## Generate WebhookConfiguration, ClusterRole and CustomResourceDefinition objects.
	$(CONTROLLER_GEN) $(CRD_OPTIONS) rbac:roleName=manager-role webhook paths="./..." output:crd:artifacts:config=config/crd/bases

generate: controller-gen ## Generate code containing DeepCopy, DeepCopyInto, and DeepCopyObject method implementations.
	$(CONTROLLER_GEN) object:headerFile="hack/boilerplate.go.txt" paths="./..."

fmt: ## Run go fmt against code.
	go fmt ./...

vet: ## Run go vet against code.
	go vet ./...

ENVTEST_ASSETS_DIR=$(shell pwd)/testbin
test: manifests generate fmt vet ## Run tests.
	mkdir -p ${ENVTEST_ASSETS_DIR}
	test -f ${ENVTEST_ASSETS_DIR}/setup-envtest.sh || curl -sSLo ${ENVTEST_ASSETS_DIR}/setup-envtest.sh https://raw.githubusercontent.com/kubernetes-sigs/controller-runtime/v0.8.3/hack/setup-envtest.sh
	source ${ENVTEST_ASSETS_DIR}/setup-envtest.sh; fetch_envtest_tools $(ENVTEST_ASSETS_DIR); setup_envtest_env $(ENVTEST_ASSETS_DIR); go test ./... -coverprofile cover.out

##@ Build

build: generate fmt vet ## Build manager binary.
	go build -o bin/manager main.go

run: manifests generate fmt vet ## Run a controller from your host.
	go run ./main.go

docker-build: test-infra/test ## Build docker image with the manager.
	docker build -t ${IMG} .

docker-push: ## Push docker image with the manager.
	docker push ${IMG}

##@ Deployment

install: manifests kustomize ## Install CRDs into the K8s cluster specified in ~/.kube/config.
	$(KUSTOMIZE) build config/crd | kubectl apply -f -

uninstall: manifests kustomize ## Uninstall CRDs from the K8s cluster specified in ~/.kube/config.
	$(KUSTOMIZE) build config/crd | kubectl delete -f -

deploy: manifests kustomize ## Deploy controller to the K8s cluster specified in ~/.kube/config.
	cd config/manager && $(KUSTOMIZE) edit set image controller=${IMG}
	mkdir -p manifests
	$(KUSTOMIZE) build config/default > ./manifests/manifests.gen.yaml

undeploy: ## Undeploy controller from the K8s cluster specified in ~/.kube/config.
	kubectl delete -f ./manifests/manifests.gen.yaml

setup-webhook: install deploy push
	kubectl apply -f ./manifests/manifests.gen.yaml

CONTROLLER_GEN = $(shell pwd)/bin/controller-gen
controller-gen: ## Download controller-gen locally if necessary.
	$(call go-get-tool,$(CONTROLLER_GEN),sigs.k8s.io/controller-tools/cmd/controller-gen@v0.4.1)

KUSTOMIZE = $(shell pwd)/bin/kustomize
kustomize: ## Download kustomize locally if necessary.
	$(call go-get-tool,$(KUSTOMIZE),sigs.k8s.io/kustomize/kustomize/v3@v3.8.7)

# go-get-tool will 'go get' any package $2 and install it to $1.
PROJECT_DIR := $(shell dirname $(abspath $(lastword $(MAKEFILE_LIST))))
define go-get-tool
@[ -f $(1) ] || { \
set -e ;\
TMP_DIR=$$(mktemp -d) ;\
cd $$TMP_DIR ;\
go mod init tmp ;\
echo "Downloading $(2)" ;\
GOBIN=$(PROJECT_DIR)/bin go get $(2) ;\
rm -rf $$TMP_DIR ;\
}
endef

CERT_MANAGER_VERSION = $(shell curl -sL https://github.com/cert-manager/cert-manager/releases | grep -o 'releases/download/v[0-9]*.[0-9]*.[0-9]*/' | sort -V | tail -1)
local-cluster-setup:
	@echo "\n♻️  Creating Kubernetes cluster 'local'..."
	kind create cluster --config=./test-infra/config/cluster/kind-cluster.yaml
	@echo "\n♻️  Installing Nginx..."
	curl -sL https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml > ./test-infra/config/cluster/nginx.yaml
	kubectl apply -f ./test-infra/config/cluster/nginx.yaml
	@echo "\n♻️  Installing CertManager..."
	curl -sL https://github.com/cert-manager/cert-manager/${CERT_MANAGER_VERSION}/cert-manager.yaml > ./test-infra/config/cluster/cert-manager.yaml
	kubectl apply -f ./test-infra/config/cluster/cert-manager.yaml

local-cluster-tear-down: undeploy uninstall
	@echo "\n♻️  Uninstalling Nginx..."
	kubectl delete -f ./test-infra/config/cluster/nginx.yaml
	@echo "\n♻️  Uninstalling CertManager..."
	kubectl delete -f ./test-infra/config/cluster/cert-manager.yaml
	@echo "\n♻️  Deleting Kubernetes cluster..."
	kind delete cluster --name=local

push: docker-build
	@echo "\n📦 Pushing admission-webhook image into Kind's Docker daemon..."
	kind load docker-image ${IMG} --name local

target-dir:
	mkdir -p target

generate-secret: target-dir
	@echo "\n♻️  Creating hmac secret..."
	openssl rand -hex 20 > ./target/hmac-secret
	kubectl create secret generic hmac-token --from-file=hmac=./target/hmac-secret -n prow --dry-run=client -o yaml > target/hmac-secret.yaml
	cat ./target/hmac-secret

setup-prow:
	@echo "\n♻️  Installing ProwJob CRD..."
	kubectl apply --server-side=true -f test-infra/config/prow/crds
	@echo "\n♻️  Creating namespaces..."
	kubectl apply --server-side=true -f test-infra/config/prow/namespace.yaml
	@echo "\n♻️  Creating Secrets..."
	kubectl apply -f target/hmac-secret.yaml,target/github-token.yaml
	@echo "\n♻️  Creating Configs..."
	kubectl apply -f test-infra/config/config.yaml,test-infra/config/plugins.yaml
	@echo "\n♻️  Installing prow core components..."
	kubectl apply -f test-infra/config/prow


uninstall-prow:
	@echo "\n♻️  Uninstalling prow components..."
	kubectl delete -f test-infra/config/prow
	@echo "\n♻️  deleting Secrets..."
	kubectl delete -f target/hmac-secret.yaml,target/secrets.yaml
	@echo "\n♻️  Uninstalling ProwJob CRD..."
	kubectl delete --server-side=true -f test-infra/config/prow/crds
