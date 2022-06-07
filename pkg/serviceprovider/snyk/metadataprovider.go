package snyk

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"

	api "github.com/redhat-appstudio/service-provider-integration-operator/api/v1beta1"
	"github.com/redhat-appstudio/service-provider-integration-operator/pkg/serviceprovider"
	"github.com/redhat-appstudio/service-provider-integration-operator/pkg/spi-shared/tokenstorage"
)

type metadataProvider struct {
	httpClient   *http.Client
	tokenStorage tokenstorage.TokenStorage
}

var _ serviceprovider.MetadataProvider = (*metadataProvider)(nil)
var snykUserApiEndpoint *url.URL

func init() {
	qUrl, err := url.Parse("https://snyk.io/api/v1/user/me")
	if err != nil {
		panic(err)
	}
	snykUserApiEndpoint = qUrl
}

func (s metadataProvider) Fetch(ctx context.Context, token *api.SPIAccessToken) (*api.TokenMetadata, error) {
	data, err := s.tokenStorage.Get(ctx, token)
	if err != nil {
		return nil, err
	}

	if data == nil {
		return nil, err
	}

	userid, username, err := s.fetchUser(data.AccessToken)
	if err != nil {
		return nil, err
	}

	metadata := token.Status.TokenMetadata
	if metadata == nil {
		metadata = &api.TokenMetadata{}
		token.Status.TokenMetadata = metadata
	}
	metadata.Username = username
	metadata.UserId = userid
	return metadata, nil
}

func (s metadataProvider) fetchUser(accessToken string) (userId string, userName string, err error) {
	var res *http.Response
	res, err = s.httpClient.Do(&http.Request{
		Method: "GET",
		URL:    snykUserApiEndpoint,
		Header: map[string][]string{
			"Authorization": {"token " + accessToken},
		},
	})
	if err != nil {
		return
	}

	if res.StatusCode != 200 {
		// this should never happen because our http client should already handle the errors so we return a hard
		// error that will cause the whole fetch to fail
		err = fmt.Errorf("unexpected response from the snyk api. status code: %d", res.StatusCode)
		return
	}

	content := map[string]interface{}{}
	if err = json.NewDecoder(res.Body).Decode(&content); err != nil {
		return
	}

	userId = content["id"].(string)
	userName = content["username"].(string)

	return
}
