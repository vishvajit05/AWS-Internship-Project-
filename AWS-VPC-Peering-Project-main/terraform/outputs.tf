output "vpc_a_id" {
  description = "ID of VPC A (Requester VPC - 10.10.0.0/16)"
  value       = aws_vpc.vpc_a.id
}

output "vpc_b_id" {
  description = "ID of VPC B (Accepter VPC - 10.20.0.0/16)"
  value       = aws_vpc.vpc_b.id
}

output "peering_connection_id" {
  description = "ID of the established VPC Peering connection (ewb-a-b-peer)"
  value       = aws_vpc_peering_connection.peer.id
}

output "bastion_public_ip" {
  description = "Public IPv4 address assigned to the Bastion host for administrative SSH jump access"
  value       = aws_instance.bastion.public_ip
}

output "bastion_instance_id" {
  description = "Instance ID of the Bastion jump host (ewb-bastion)"
  value       = aws_instance.bastion.id
}

output "app_a_instance_id" {
  description = "Instance ID of Private Application Instance A (ewb-app-a)"
  value       = aws_instance.app_a.id
}

output "app_b_instance_id" {
  description = "Instance ID of Private Application Instance B (ewb-app-b)"
  value       = aws_instance.app_b.id
}
