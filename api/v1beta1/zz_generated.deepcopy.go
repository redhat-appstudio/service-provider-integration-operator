//go:build !ignore_autogenerated
// +build !ignore_autogenerated

/*
Copyright 2021.

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

// Code generated by controller-gen. DO NOT EDIT.

package v1beta1

import (
	runtime "k8s.io/apimachinery/pkg/runtime"
)

// DeepCopyInto is an autogenerated deepcopy function, copying the receiver, writing into out. in must be non-nil.
func (in *AccessTokenSecret) DeepCopyInto(out *AccessTokenSecret) {
	*out = *in
	out.TypeMeta = in.TypeMeta
	in.ObjectMeta.DeepCopyInto(&out.ObjectMeta)
	in.Spec.DeepCopyInto(&out.Spec)
	out.Status = in.Status
}

// DeepCopy is an autogenerated deepcopy function, copying the receiver, creating a new AccessTokenSecret.
func (in *AccessTokenSecret) DeepCopy() *AccessTokenSecret {
	if in == nil {
		return nil
	}
	out := new(AccessTokenSecret)
	in.DeepCopyInto(out)
	return out
}

// DeepCopyObject is an autogenerated deepcopy function, copying the receiver, creating a new runtime.Object.
func (in *AccessTokenSecret) DeepCopyObject() runtime.Object {
	if c := in.DeepCopy(); c != nil {
		return c
	}
	return nil
}

// DeepCopyInto is an autogenerated deepcopy function, copying the receiver, writing into out. in must be non-nil.
func (in *AccessTokenSecretFieldMapping) DeepCopyInto(out *AccessTokenSecretFieldMapping) {
	*out = *in
}

// DeepCopy is an autogenerated deepcopy function, copying the receiver, creating a new AccessTokenSecretFieldMapping.
func (in *AccessTokenSecretFieldMapping) DeepCopy() *AccessTokenSecretFieldMapping {
	if in == nil {
		return nil
	}
	out := new(AccessTokenSecretFieldMapping)
	in.DeepCopyInto(out)
	return out
}

// DeepCopyInto is an autogenerated deepcopy function, copying the receiver, writing into out. in must be non-nil.
func (in *AccessTokenSecretList) DeepCopyInto(out *AccessTokenSecretList) {
	*out = *in
	out.TypeMeta = in.TypeMeta
	in.ListMeta.DeepCopyInto(&out.ListMeta)
	if in.Items != nil {
		in, out := &in.Items, &out.Items
		*out = make([]AccessTokenSecret, len(*in))
		for i := range *in {
			(*in)[i].DeepCopyInto(&(*out)[i])
		}
	}
}

// DeepCopy is an autogenerated deepcopy function, copying the receiver, creating a new AccessTokenSecretList.
func (in *AccessTokenSecretList) DeepCopy() *AccessTokenSecretList {
	if in == nil {
		return nil
	}
	out := new(AccessTokenSecretList)
	in.DeepCopyInto(out)
	return out
}

// DeepCopyObject is an autogenerated deepcopy function, copying the receiver, creating a new runtime.Object.
func (in *AccessTokenSecretList) DeepCopyObject() runtime.Object {
	if c := in.DeepCopy(); c != nil {
		return c
	}
	return nil
}

// DeepCopyInto is an autogenerated deepcopy function, copying the receiver, writing into out. in must be non-nil.
func (in *AccessTokenSecretSpec) DeepCopyInto(out *AccessTokenSecretSpec) {
	*out = *in
	in.Target.DeepCopyInto(&out.Target)
}

// DeepCopy is an autogenerated deepcopy function, copying the receiver, creating a new AccessTokenSecretSpec.
func (in *AccessTokenSecretSpec) DeepCopy() *AccessTokenSecretSpec {
	if in == nil {
		return nil
	}
	out := new(AccessTokenSecretSpec)
	in.DeepCopyInto(out)
	return out
}

// DeepCopyInto is an autogenerated deepcopy function, copying the receiver, writing into out. in must be non-nil.
func (in *AccessTokenSecretStatus) DeepCopyInto(out *AccessTokenSecretStatus) {
	*out = *in
	out.ObjectRef = in.ObjectRef
}

// DeepCopy is an autogenerated deepcopy function, copying the receiver, creating a new AccessTokenSecretStatus.
func (in *AccessTokenSecretStatus) DeepCopy() *AccessTokenSecretStatus {
	if in == nil {
		return nil
	}
	out := new(AccessTokenSecretStatus)
	in.DeepCopyInto(out)
	return out
}

// DeepCopyInto is an autogenerated deepcopy function, copying the receiver, writing into out. in must be non-nil.
func (in *AccessTokenSecretStatusObjectRef) DeepCopyInto(out *AccessTokenSecretStatusObjectRef) {
	*out = *in
}

// DeepCopy is an autogenerated deepcopy function, copying the receiver, creating a new AccessTokenSecretStatusObjectRef.
func (in *AccessTokenSecretStatusObjectRef) DeepCopy() *AccessTokenSecretStatusObjectRef {
	if in == nil {
		return nil
	}
	out := new(AccessTokenSecretStatusObjectRef)
	in.DeepCopyInto(out)
	return out
}

// DeepCopyInto is an autogenerated deepcopy function, copying the receiver, writing into out. in must be non-nil.
func (in *AccessTokenTarget) DeepCopyInto(out *AccessTokenTarget) {
	*out = *in
	if in.ConfigMap != nil {
		in, out := &in.ConfigMap, &out.ConfigMap
		*out = new(AccessTokenTargetConfigMap)
		(*in).DeepCopyInto(*out)
	}
	if in.Secret != nil {
		in, out := &in.Secret, &out.Secret
		*out = new(AccessTokenTargetSecret)
		(*in).DeepCopyInto(*out)
	}
	if in.Containers != nil {
		in, out := &in.Containers, &out.Containers
		*out = new(AccessTokenTargetContainers)
		(*in).DeepCopyInto(*out)
	}
}

// DeepCopy is an autogenerated deepcopy function, copying the receiver, creating a new AccessTokenTarget.
func (in *AccessTokenTarget) DeepCopy() *AccessTokenTarget {
	if in == nil {
		return nil
	}
	out := new(AccessTokenTarget)
	in.DeepCopyInto(out)
	return out
}

// DeepCopyInto is an autogenerated deepcopy function, copying the receiver, writing into out. in must be non-nil.
func (in *AccessTokenTargetConfigMap) DeepCopyInto(out *AccessTokenTargetConfigMap) {
	*out = *in
	if in.Labels != nil {
		in, out := &in.Labels, &out.Labels
		*out = make(map[string]string, len(*in))
		for key, val := range *in {
			(*out)[key] = val
		}
	}
	if in.Annotations != nil {
		in, out := &in.Annotations, &out.Annotations
		*out = make(map[string]string, len(*in))
		for key, val := range *in {
			(*out)[key] = val
		}
	}
	out.Fields = in.Fields
}

// DeepCopy is an autogenerated deepcopy function, copying the receiver, creating a new AccessTokenTargetConfigMap.
func (in *AccessTokenTargetConfigMap) DeepCopy() *AccessTokenTargetConfigMap {
	if in == nil {
		return nil
	}
	out := new(AccessTokenTargetConfigMap)
	in.DeepCopyInto(out)
	return out
}

// DeepCopyInto is an autogenerated deepcopy function, copying the receiver, writing into out. in must be non-nil.
func (in *AccessTokenTargetContainers) DeepCopyInto(out *AccessTokenTargetContainers) {
	*out = *in
	in.PodLabels.DeepCopyInto(&out.PodLabels)
	if in.Containers != nil {
		in, out := &in.Containers, &out.Containers
		*out = make([]string, len(*in))
		copy(*out, *in)
	}
}

// DeepCopy is an autogenerated deepcopy function, copying the receiver, creating a new AccessTokenTargetContainers.
func (in *AccessTokenTargetContainers) DeepCopy() *AccessTokenTargetContainers {
	if in == nil {
		return nil
	}
	out := new(AccessTokenTargetContainers)
	in.DeepCopyInto(out)
	return out
}

// DeepCopyInto is an autogenerated deepcopy function, copying the receiver, writing into out. in must be non-nil.
func (in *AccessTokenTargetSecret) DeepCopyInto(out *AccessTokenTargetSecret) {
	*out = *in
	if in.Labels != nil {
		in, out := &in.Labels, &out.Labels
		*out = make(map[string]string, len(*in))
		for key, val := range *in {
			(*out)[key] = val
		}
	}
	if in.Annotations != nil {
		in, out := &in.Annotations, &out.Annotations
		*out = make(map[string]string, len(*in))
		for key, val := range *in {
			(*out)[key] = val
		}
	}
	out.Fields = in.Fields
}

// DeepCopy is an autogenerated deepcopy function, copying the receiver, creating a new AccessTokenTargetSecret.
func (in *AccessTokenTargetSecret) DeepCopy() *AccessTokenTargetSecret {
	if in == nil {
		return nil
	}
	out := new(AccessTokenTargetSecret)
	in.DeepCopyInto(out)
	return out
}
