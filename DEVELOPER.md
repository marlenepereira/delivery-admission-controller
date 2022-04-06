## Debugging Webhooks in your IDE
There is a challenge when developing HTTP callback servers locally since the kubernetes API server needs to authenticate
to the webhook server.

- If your validating webhook is also a controller, you can call the validation logic from within the controller's
  reconciling loop to test your validation logic. the downside is that the resources is created even if invalid, and
  you'd have to delete it everytime you test.
- Another option is to configure the validating webhook to send the request to a [Smee channel][00]
  that plays back the request to the local webhook server running in your IDE. If you do this, you'll have to configure
  the webhook `clientConfig` using an URL instead of a Kubernetes Service, as per the [Kubernetes docs][01]:
```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingWebhookConfiguration
...
webhooks:
- name: my-webhook.example.com
  clientConfig:
    url: "https://my-smee-channel"
  ...
```
[00]: https://docs.github.com/en/developers/apps/getting-started-with-apps/setting-up-your-development-environment-to-create-a-github-app#step-1-start-a-new-smee-channel
[01]: https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/#url
