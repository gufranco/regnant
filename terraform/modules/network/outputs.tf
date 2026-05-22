output "vpc_id" {
  description = "VPC identifier."
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "VPC CIDR block."
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet identifiers."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet identifiers."
  value       = aws_subnet.private[*].id
}

output "availability_zones" {
  description = "Availability zones used by the module."
  value = [
    for s in aws_subnet.public : s.availability_zone
  ]
}

output "internet_gateway_id" {
  description = "Internet gateway identifier."
  value       = aws_internet_gateway.main.id
}

output "public_route_table_id" {
  description = "Public route table identifier."
  value       = aws_route_table.public.id
}

output "private_route_table_id" {
  description = "Private route table identifier."
  value       = aws_route_table.private.id
}

output "vpc_endpoint_ids" {
  description = "Map of VPC endpoint identifiers by service."
  value = {
    s3       = try(aws_vpc_endpoint.s3[0].id, null)
    dynamodb = try(aws_vpc_endpoint.dynamodb[0].id, null)
    sqs      = try(aws_vpc_endpoint.sqs[0].id, null)
  }
}
