//
// Copyright (c) 2021 Red Hat, Inc.
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package common

import (
	"context"
	"fmt"

	api "github.com/redhat-appstudio/service-provider-integration-operator/api/v1beta1"
	"github.com/redhat-appstudio/service-provider-integration-operator/pkg/serviceprovider"
	"github.com/redhat-appstudio/service-provider-integration-operator/pkg/spi-shared/config"
	"k8s.io/client-go/rest"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/log"
)

// Common is a unified provider implementation for any URL-based tokens and only supports
// manual upload of token data. Matching is done only by URL of the provider, so it is possible to have
// only one token for particular URL in the given namespace.
type Common struct {
	Configuration config.Configuration
	lookup        serviceprovider.GenericLookup
	httpClient    rest.HTTPClient
	repoUrl       string
}

var Initializer = serviceprovider.Initializer{
	Constructor: serviceprovider.ConstructorFunc(newCommon),
}

func newCommon(factory *serviceprovider.Factory, repoUrl string) (serviceprovider.ServiceProvider, error) {

	cache := serviceprovider.NewMetadataCache(factory.KubernetesClient, &serviceprovider.NeverMetadataExpirationPolicy{})
	return &Common{
		Configuration: factory.Configuration,
		lookup: serviceprovider.GenericLookup{
			ServiceProviderType: api.ServiceProviderTypeCommon,
			TokenFilter:         &tokenFilter{},
			RepoHostParser:      serviceprovider.RepoHostParserFunc(serviceprovider.RepoHostFromSchemelessUrl),
			MetadataCache:       &cache,
			MetadataProvider: &metadataProvider{
				tokenStorage: factory.TokenStorage,
			},
		},
		httpClient: factory.HttpClient,
		repoUrl:    repoUrl,
	}, nil
}

var _ serviceprovider.ConstructorFunc = newCommon

func (g *Common) GetOAuthEndpoint() string {
	return ""
}

func (g *Common) GetBaseUrl() string {
	base, err := serviceprovider.GetHostWithScheme(g.repoUrl)
	if err != nil {
		return ""
	}
	return base
}

func (g *Common) GetType() api.ServiceProviderType {
	return api.ServiceProviderTypeCommon
}

func (g *Common) TranslateToScopes(_ api.Permission) []string {
	return []string{}
}

func (g *Common) LookupToken(ctx context.Context, cl client.Client, binding *api.SPIAccessTokenBinding) (*api.SPIAccessToken, error) {
	tokens, err := g.lookup.Lookup(ctx, cl, binding)
	if err != nil {
		return nil, err
	}

	if len(tokens) == 0 {
		return nil, nil
	}

	return &tokens[0], nil
}

func (g *Common) PersistMetadata(ctx context.Context, _ client.Client, token *api.SPIAccessToken) error {
	return g.lookup.PersistMetadata(ctx, token)
}

func (g *Common) GetServiceProviderUrlForRepo(repoUrl string) (string, error) {
	return serviceprovider.GetHostWithScheme(repoUrl)
}

func (g *Common) CheckRepositoryAccess(ctx context.Context, _ client.Client, accessCheck *api.SPIAccessCheck) (*api.SPIAccessCheckStatus, error) {
	repoUrl := accessCheck.Spec.RepoUrl
	log.FromContext(ctx).Info(fmt.Sprintf("%s is a generic service provider. Access check for generic service providers is not supported.", repoUrl))
	return &api.SPIAccessCheckStatus{
		Accessibility: api.SPIAccessCheckAccessibilityUnknown,
		ErrorReason:   api.SPIAccessCheckErrorNotImplemented,
		ErrorMessage:  "Access check for generic provider is not implemented.",
	}, nil
}

func (g *Common) MapToken(_ context.Context, _ *api.SPIAccessTokenBinding, token *api.SPIAccessToken, tokenData *api.Token) (serviceprovider.AccessTokenMapper, error) {
	return serviceprovider.DefaultMapToken(token, tokenData)
}

func (g *Common) Validate(_ context.Context, _ serviceprovider.Validated) (serviceprovider.ValidationResult, error) {
	return serviceprovider.ValidationResult{}, nil
}
