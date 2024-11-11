package main

import (
	"context"
	"encoding/json"
	"io"
	"log"
	"net/http"
	"strings"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
)

type Response struct {
	Message json.RawMessage `json:"message"`
}

func handler(ctx context.Context, request events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	log.Printf("Fetching from Google OpenID configuration")
	resp, err := http.Get("https://accounts.google.com/.well-known/openid-configuration")
	if err != nil {
		return events.APIGatewayProxyResponse{StatusCode: 500}, err
	}
	defer resp.Body.Close()

	bodyBytes, err := io.ReadAll(resp.Body)
	if err != nil {
		return events.APIGatewayProxyResponse{StatusCode: 500}, err
	}
	log.Printf("Successfully read response body from Google")

	var originalJSON map[string]interface{}
	if err := json.Unmarshal(bodyBytes, &originalJSON); err != nil {
		return events.APIGatewayProxyResponse{StatusCode: 500}, err
	}
	log.Printf("Parsed JSON: %+v", originalJSON)

	// Lambda署名を追加
	ipResp, err := http.Get("https://checkip.amazonaws.com")
	if err != nil {
		return events.APIGatewayProxyResponse{StatusCode: 500}, err
	}
	defer ipResp.Body.Close()

	ipBytes, err := io.ReadAll(ipResp.Body)
	if err != nil {
		return events.APIGatewayProxyResponse{StatusCode: 500}, err
	}
	ipAddress := string(ipBytes)
	ipAddress = strings.TrimSpace(ipAddress)

	// 追加情報をレスポンスに埋め込む
	originalJSON["extended_info"] = map[string]string{
		"_fetched_by": "AWS Lambda (api-gateway-in-vpc)",
		"nat_gateway": "used",
		"ip_type":     "static",
		"ip_address":  ipAddress,
		"description": "Outbound IP address is fixed via NAT Gateway with Elastic IP",
	}
	originalJSON["lambda_authorizer"] = request.RequestContext.Authorizer

	modifiedBody, err := json.Marshal(originalJSON)
	if err != nil {
		return events.APIGatewayProxyResponse{StatusCode: 500}, err
	}
	log.Printf("Returning modified JSON with _fetched_by signature")

	return events.APIGatewayProxyResponse{
		StatusCode: 200,
		Body:       string(modifiedBody),
		Headers: map[string]string{
			"Content-Type": "application/json",
		},
	}, nil
}

func main() {
	lambda.Start(handler)
}
