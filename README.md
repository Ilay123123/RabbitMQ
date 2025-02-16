# RabbitMQ

# AWS RabbitMQ Cluster with Terraform

This Terraform configuration sets up a highly available RabbitMQ cluster on AWS using Docker containers and auto-scaling groups.

## Architecture Overview

The infrastructure includes:
- VPC with a public subnet
- Auto Scaling Group for RabbitMQ nodes
- Network Load Balancer
- Security Groups for RabbitMQ communication
- Docker-based RabbitMQ instances with management plugin

## Prerequisites

- Terraform installed (version 0.12 or later)
- AWS CLI configured with appropriate credentials
- Docker and Docker Compose (for local testing if needed)

## Infrastructure Components

### Networking
- VPC with CIDR block 10.0.0.0/16
- Public subnet in a single availability zone
- Internet Gateway for public internet access
- Route table for internet access

### Security
- Security group allowing:
  - RabbitMQ AMQP port (5672)
  - Management interface port (15672)
  - Cluster communication port (25672)
  - All outbound traffic

### Compute
- Launch Template with Ubuntu AMI
- Auto Scaling Group for managing RabbitMQ instances
- Network Load Balancer for distributing traffic

### RabbitMQ Configuration
- RabbitMQ 3.9 with management plugin
- AWS peer discovery plugin for cluster formation
- Docker-based deployment
- Default credentials (should be changed in production):
  - Username: admin
  - Password: admin123

## Usage

1. Initialize Terraform:
```bash
terraform init
```

2. Review the execution plan:
```bash
terraform plan
```

3. Apply the configuration:
```bash
terraform apply
```

## Variables

Configure the following variables in `terraform.tfvars`:

- `aws_region`: AWS region for deployment
- `ami_id`: Ubuntu AMI ID for your region
- `cluster_size`: Desired number of RabbitMQ nodes
- `min_size`: Minimum number of nodes
- `max_size`: Maximum number of nodes

## Accessing the Cluster

- AMQP endpoint: `<load-balancer-dns>:5672`
- Management UI: `http://<instance-public-ip>:15672`

## Security Considerations

For production use:
1. Modify security group rules to restrict access
2. Change default RabbitMQ credentials
3. Enable SSL/TLS for AMQP and management interface
4. Consider using private subnets with VPN or Direct Connect
5. Implement proper monitoring and logging

## Cleanup

To destroy the infrastructure:
```bash
terraform destroy
```

## Notes

- The cluster uses AWS auto-discovery for node formation
- Instances are tagged with Role=rabbitmq for discovery
- Data persistence is not configured (add EBS volumes if needed)
- Consider multi-AZ deployment for production use

## Contributing

Feel free to submit issues and enhancement requests.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
