package terratest

import (
	"context"
	"testing"

	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/aws/aws-sdk-go-v2/service/sqs"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/require"
)

// TestOsbModule applies the osb module and asserts every primitive
// shows up against LocalStack.
func TestOsbModule(t *testing.T) {
	t.Parallel()

	// The osb module needs KMS arns and IAM role names from the security
	// module; pass plausible LocalStack values for the standalone test.
	tfOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../../terraform/envs/local",
		Vars: map[string]interface{}{
			"envoy_instance_count":     1,
			"osb_artifact_bucket_name": "regnant-test-osb-artifacts",
		},
		EnvVars: map[string]string{
			"AWS_ACCESS_KEY_ID":     "test",
			"AWS_SECRET_ACCESS_KEY": "test",
			"AWS_DEFAULT_REGION":    "us-east-1",
		},
	})
	defer terraform.Destroy(t, tfOptions)
	terraform.InitAndApply(t, tfOptions)

	bucket := terraform.Output(t, tfOptions, "osb_artifact_bucket")
	instancesTable := terraform.Output(t, tfOptions, "osb_instances_table")
	bindingsTable := terraform.Output(t, tfOptions, "osb_bindings_table")
	queueURL := terraform.Output(t, tfOptions, "osb_provision_queue_url")

	require.NotEmpty(t, bucket)
	require.NotEmpty(t, instancesTable)
	require.NotEmpty(t, bindingsTable)
	require.NotEmpty(t, queueURL)

	ctx := context.Background()

	// S3 bucket reachable.
	s3client := newS3Client(t)
	_, err := s3client.HeadBucket(ctx, &s3.HeadBucketInput{Bucket: &bucket})
	require.NoError(t, err)

	// DynamoDB tables ACTIVE.
	ddb := newDynamoDBClient(t)
	for _, name := range []string{instancesTable, bindingsTable} {
		out, derr := ddb.DescribeTable(ctx, &dynamodb.DescribeTableInput{TableName: &name})
		require.NoError(t, derr)
		require.Equal(t, "ACTIVE", string(out.Table.TableStatus))
	}

	// SQS queue exists.
	sqsclient := newSQSClient(t)
	_, err = sqsclient.GetQueueAttributes(ctx, &sqs.GetQueueAttributesInput{QueueUrl: &queueURL})
	require.NoError(t, err)
}
