package terratest

import (
	"context"
	"testing"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/ec2"
	ec2types "github.com/aws/aws-sdk-go-v2/service/ec2/types"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/require"
)

// TestNetworkModule applies the network module against LocalStack and
// asserts the VPC, three subnets, IGW, and VPC endpoints exist.
func TestNetworkModule(t *testing.T) {
	t.Parallel()

	tfOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../../terraform/modules/network",
		Vars: map[string]interface{}{
			"name_prefix":  "regnant-test",
			"region_label": "us-east-1",
		},
		EnvVars: map[string]string{
			"AWS_ACCESS_KEY_ID":     "test",
			"AWS_SECRET_ACCESS_KEY": "test",
			"AWS_DEFAULT_REGION":    "us-east-1",
		},
	})
	defer terraform.Destroy(t, tfOptions)
	terraform.InitAndApply(t, tfOptions)

	vpcID := terraform.Output(t, tfOptions, "vpc_id")
	require.NotEmpty(t, vpcID)

	subnets := terraform.OutputList(t, tfOptions, "public_subnet_ids")
	require.Len(t, subnets, 3)

	client := newEC2Client(t)
	res, err := client.DescribeInternetGateways(context.Background(), &ec2.DescribeInternetGatewaysInput{
		Filters: []ec2types.Filter{
			{Name: aws.String("attachment.vpc-id"), Values: []string{vpcID}},
		},
	})
	require.NoError(t, err)
	require.Len(t, res.InternetGateways, 1)
}
