# Test Infra Config
The `/cluster` directory contains YAML configuration to create a KinD cluster and the `/prow` contains the Kubernetes resource definition for Prow running on KinD.

# Setting up the cluster
Create a KinD cluster by running:
```shell
make local-cluster-setup
```
This command will create a KinD cluster with [port mapping for ingress][00] and deploy CertManager and Nginx.

# Setting up Prow as a GitHub APP
Instructions in this section is based on the `kubernetes/test-infra` [getting_started_deploy.md][02] guide for Prow adapted for local KinD.

### Create the GitHub APP
Create a GitHub app under your personal account or your organization following instructions [here][01].

* Add a placeholder `Webhook URL`, i.e. `https://example.com`, we'll update it later.
* Leave the `Webhook secret (optional)` empty for now and we'll update it later.
* The permissions required by Prow are described [here][05].
The only thing we will change is the `Administration (Read-Only)` to `Administration permission (read & write)`. This is [required by the branch protector
component][04].
* In `Subscribe to events` select all events.
* Once you created the app, click `Generate Private Key` and save the private key together with the App ID in the top of the page.
We will use these two to create the Kubernetes GitHub secrets needed for Prow.
* Install the GitHub APP in your repo by following [this][06] guide.

### Create the GitHub Kubernetes secret
1. Create the HMAC secret by running:
```shell
make generate-secret
```
This command will print the generated secret into stdout, copy the secret and add it to the `Webhook secret (optional)` on the GitHub APP we created above.
2. Generate the GitHub token Kubernetes secret by running the command:
```shell
kubectl create secret generic github-token --from-file=cert=<path-to-your-private-key> --from-literal=appid=<gh-app-id> -n prow --dry-run=client -o yaml > ./target/github-token.yaml
```
Replace the `<path-to-your-private-key>` with the path to where the GitHub private key we generated is stored. Also, replace `<gh-app-id>` with the app id.

### Install the Prow
Once the Kubernetes secrets are created in the `./target` directory, run the following command to setup Prow:
```shell
make setup-prow
```
The prow components are deployed in the `prow` namespace. Once pods are running, i.e. deck, you can access the Deck dashboard from `localhost`.
You can look at the access logs by checking the nginx pods logs in the `ingress-nginx` namespace.

### Connecting GitHub webhook with Prow running in KinD
The KinD cluster ingress is setup so that requests to "/" on localhost:80 routes to Deck and `/hook` to the Prow Hook component.
Please refer to the configuration in `test-infra/config/prow/ingress.yaml`.
In order to receive requests from GitHub into our local cluster, we can use a [smee channel](https://smee.io/).

1. Start a new Smee channel [here](https://smee.io/).
2. Copy the URL and update the `Webhook URL` of GitHub APP we created.
3. Install the smee CLI:
```shell
$ npm install --global smee-client
```
4. Run the smee command below to forward webhooks from smee.io to your local development environment.
```shell
smee --url https://smee.io/my-channel  --path /hook --port 80
```
The output would look like:
```shell
Forwarding https://smee.io/my-channel to http://127.0.0.1:80/hook
Connected https://smee.io/my-channel
```
Note that we only forward traffic that is intended to Hook component, i.e. `/hook` path, since this component handles webhook events.
At this point, the Hook component running in the local KinD cluster should be ready to receive events.


[00]: https://kind.sigs.k8s.io/docs/user/ingress/#ingress-nginx
[01]: https://docs.github.com/en/developers/apps/building-github-apps/creating-a-github-app
[02]: https://github.com/kubernetes/test-infra/blob/master/prow/getting_started_deploy.md
[04]: https://docs.github.com/en/rest/branches/branch-protection#update-branch-protection
[05]: https://github.com/kubernetes/test-infra/blob/master/prow/getting_started_deploy.md#github-app
[06]: https://github.com/kubernetes/test-infra/blob/master/prow/getting_started_deploy.md#install-prow-for-a-github-organization-or-repo
