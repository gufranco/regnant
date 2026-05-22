package terratest

import (
	"context"
	"net/url"
	"os"
	"testing"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/credentials"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/ec2"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/aws/aws-sdk-go-v2/service/sqs"
	"github.com/stretchr/testify/require"
)

func localstackEndpoint() string {
	if u := os.Getenv("AWS_ENDPOINT_URL"); u != "" {
		return u
	}
	return "http://localhost:4566"
}

func awsConfig(t *testing.T) aws.Config {
	t.Helper()
	endpoint := localstackEndpoint()
	if _, err := url.Parse(endpoint); err != nil {
		t.Fatalf("invalid AWS_ENDPOINT_URL: %v", err)
	}
	cfg, err := config.LoadDefaultConfig(
		context.Background(),
		config.WithRegion("us-east-1"),
		config.WithCredentialsProvider(credentials.NewStaticCredentialsProvider("test", "test", "")),
	)
	require.NoError(t, err)
	cfg.BaseEndpoint = aws.String(endpoint)
	return cfg
}

func newEC2Client(t *testing.T) *ec2.Client { return ec2.NewFromConfig(awsConfig(t)) }
func newS3Client(t *testing.T) *s3.Client {
	return s3.NewFromConfig(awsConfig(t), func(o *s3.Options) { o.UsePathStyle = true })
}
func newSQSClient(t *testing.T) *sqs.Client { return sqs.NewFromConfig(awsConfig(t)) }
func newDynamoDBClient(t *testing.T) *dynamodb.Client {
	return dynamodb.NewFromConfig(awsConfig(t))
}
