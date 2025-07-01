/*
Copyright 2025.

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
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// EDIT THIS FILE!  THIS IS SCAFFOLDING FOR YOU TO OWN!
// NOTE: json tags are required.  Any new fields you add must have json tags for the fields to be serialized.

// LatencyCollectorSpec defines the desired state of LatencyCollector
type LatencyCollectorSpec struct {
	// INSERT ADDITIONAL SPEC FIELDS - desired state of cluster
	// Important: Run "make" to regenerate code after modifying this file

	// Foo is an example field of LatencyCollector. Edit latencycollector_types.go to remove/update
	Foo string `json:"foo,omitempty"`
}

// LatencyCollectorStatus defines the observed state of LatencyCollector
type LatencyCollectorStatus struct {
	// INSERT ADDITIONAL STATUS FIELD - define observed state of cluster
	// Important: Run "make" to regenerate code after modifying this file
}

//+kubebuilder:object:root=true
//+kubebuilder:subresource:status

// LatencyCollector is the Schema for the latencycollectors API
type LatencyCollector struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec   LatencyCollectorSpec   `json:"spec,omitempty"`
	Status LatencyCollectorStatus `json:"status,omitempty"`
}

//+kubebuilder:object:root=true

// LatencyCollectorList contains a list of LatencyCollector
type LatencyCollectorList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []LatencyCollector `json:"items"`
}

func init() {
	SchemeBuilder.Register(&LatencyCollector{}, &LatencyCollectorList{})
}
