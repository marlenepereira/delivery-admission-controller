/*
Copyright 2022.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package v1alpha1

import (
	"fmt"
	"io/ioutil"
	"k8s.io/apimachinery/pkg/runtime"
	"net/http"
	ctrl "sigs.k8s.io/controller-runtime"
	logf "sigs.k8s.io/controller-runtime/pkg/log"
	"sigs.k8s.io/controller-runtime/pkg/webhook"
)

const BASE_URL = "https://api.zippopotam.us/au"

// log is for logging in this package.
var requestlog = logf.Log.WithName("request-resource")

func (r *Request) SetupWebhookWithManager(mgr ctrl.Manager) error {
	return ctrl.NewWebhookManagedBy(mgr).
		For(r).
		Complete()
}

// EDIT THIS FILE!  THIS IS SCAFFOLDING FOR YOU TO OWN!

// TODO(user): change verbs to "verbs=create;update;delete" if you want to enable deletion validation.
// +kubebuilder:webhook:path=/validate-delivery-order-com-v1alpha1-request,mutating=false,failurePolicy=fail,sideEffects=None,groups=delivery.order.com,resources=requests,verbs=create;update,versions=v1alpha1,name=vrequest.kb.io,admissionReviewVersions={v1,v1beta1}

var _ webhook.Validator = &Request{}

// ValidateCreate implements webhook.Validator so a webhook will be registered for the type
func (r *Request) ValidateCreate() error {
	requestlog.Info("validate create", "name", r.Name)

	postcode := r.Spec.Postcode
	err := isValidateAUPostcode(postcode)
	if err != nil {
		return err
	}

	return nil
}

// ValidateUpdate implements webhook.Validator so a webhook will be registered for the type
func (r *Request) ValidateUpdate(old runtime.Object) error {
	requestlog.Info("validate update", "name", r.Name)

	postcode := r.Spec.Postcode
	err := isValidateAUPostcode(postcode)
	if err != nil {
		return err
	}
	return nil
}

// ValidateDelete implements webhook.Validator so a webhook will be registered for the type
func (r *Request) ValidateDelete() error {
	requestlog.Info("validate delete", "name", r.Name)

	// TODO(user): fill in your validation logic upon object deletion.
	return nil
}

func isValidateAUPostcode(code string) error {
	url := fmt.Sprintf("%s/%s", BASE_URL, code)
	resp, err := http.Get(url)
	if err != nil || resp.StatusCode != 200 {
		return fmt.Errorf("the postcode '%s' in the request is invalid", code)
	}
	defer resp.Body.Close()
	body, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		requestlog.Info("Couldn't read the response body")
	}

	requestlog.Info("postcode response", "body", string(body))
	return nil
}
