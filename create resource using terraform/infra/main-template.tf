# infra/main.tf

############################################
# Networking (VPC, Subnets, Gateway, NAT)  #
############################################

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-VPC"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-IGW"
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-NAT-EIP"
  }
}

# Public Subnets
resource "aws_subnet" "public" {
  count             = length(var.public_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-PublicSubnet-${count.index + 1}"
  }
}

# Private Subnets
resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.project_name}-PrivateSubnet-${count.index + 1}"
  }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id # Place NAT in the first public subnet
  depends_on    = [aws_internet_gateway.main]

  tags = {
    Name = "${var.project_name}-NATGateway"
  }
}

# Route Tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-PublicRT"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-PrivateRT"
  }
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# Data source for AZs
data "aws_availability_zones" "available" {
  state = "available"
}


############################################
# Security Groups                          #
############################################

resource "aws_security_group" "web_server_sg" {
  name        = "${replace(var.project_name, " ", "-")}-WebServerSG" # Ensure no spaces
  description = "Allow SSH and HTTP access to web server"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # WARNING: Restrict to your IP in production!
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-WebServerSG"
  }
}

resource "aws_security_group" "rds_sg" {
  name        = "${replace(var.project_name, " ", "-")}-RDSSG" # Ensure no spaces
  description = "Allow traffic from application servers to RDS"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web_server_sg.id] # Allow from web server SG
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-RDSSG"
  }
}

############################################
# EC2 Instance                             #
############################################

# Create an EC2 Key Pair
resource "aws_key_pair" "deployer" {
  key_name   = "${replace(var.project_name, " ", "-")}-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDQrI0ep3YeHiiWwMoudmTtac3XeDYmOACuoypovwyCedg/7LK5xvoaCUyCaciFZpG7ELozwsDNxu/43JxazKQb5NRGOys3cHLFTMcIW2Pqa+sPRqyn9p5rfn71AH+v0fGJkdRuEZANSzAEI0zCJyJE7PU0NXMDQ1O6D/e2gmTNx7DuIbECwJiU7rynxZupHB3eWcpYaLJRb2NeZCDnkriDCN89A/8eJnM7J7mZjftf0vYDMN3tqJ8C0zxAceI73f/t1IB1TGj6R6EL9xfJWEf+T3Hj/S0X1de0OknI0ik2BlnpVlOk7dQgUsyiKwqRM963J6PHvW210EshgnHRgLu9" # REPLACE WITH YOUR OWN PUBLIC KEY or generate locally

  # You can generate a new key pair locally if needed, e.g.:
  # $ ssh-keygen -t rsa -f ~/.ssh/id_rsa_tf -C "terraform-key"
  # Then copy the content of ~/.ssh/id_rsa_tf.pub here.
}


resource "aws_instance" "web_server" {
  ami           = var.ec2_ami_id
  instance_type = var.ec2_instance_type
  key_name      = aws_key_pair.deployer.key_name
  subnet_id     = aws_subnet.public[0].id # Place in a public subnet
  vpc_security_group_ids = [aws_security_group.web_server_sg.id]

  tags = {
    Name = "${var.project_name}-WebServer"
  }
}

############################################
# S3 Bucket                                #
############################################

resource "aws_s3_bucket" "monitor_bucket" {
  # Bucket name must be globally unique and lowercase, no spaces or underscores
  bucket = "${lower(replace(var.project_name, " ", "-"))}-${data.aws_caller_identity.current.account_id}-${var.aws_region}"

  tags = {
    Name = "${var.project_name}-S3Bucket"
  }
}

# Prevent accidental deletion of S3 bucket content
resource "aws_s3_bucket_ownership_controls" "monitor_bucket_ownership" {
  bucket = aws_s3_bucket.monitor_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "monitor_bucket_public_access" {
  bucket = aws_s3_bucket.monitor_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Used to get the AWS account ID for unique S3 bucket name
data "aws_caller_identity" "current" {}


############################################
# RDS Database                             #
############################################

resource "aws_db_subnet_group" "main" {
  # Name must only contain lowercase alphanumeric characters and hyphens, max 255 characters
  name       = "${lower(replace(var.project_name, " ", "-"))}-db-subnet-group"
  subnet_ids = [for s in aws_subnet.private : s.id] # Use all private subnets

  tags = {
    Name = "${var.project_name}-DBSubnetGroup"
  }
}

resource "aws_db_instance" "main" {
  # Identifier must only contain lowercase alphanumeric characters and hyphens, 1-63 characters
  identifier           = "${lower(replace(var.project_name, " ", "-"))}-database"
  allocated_storage    = 20
  storage_type         = "gp2"
  engine               = "mysql"
  engine_version       = "8.0.43" # Check compatible version for db.t3.micro in your region
  instance_class       = "db.t3.micro"
  # 'name' argument removed as per previous discussion for simpler deployment
  username             = var.db_master_username
  password             = var.db_master_password
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name = aws_db_subnet_group.main.name
  skip_final_snapshot  = true # Set to false for production
  publicly_accessible  = false # DB should be private
  multi_az             = false # Set to true for higher availability in production

  tags = {
    Name = "${var.project_name}-MyRDSInstance"
  }
}

############################################
# SNS Topic for Alerts                     #
############################################

resource "aws_sns_topic" "admin_alerts" {
  name = "${replace(var.project_name, " ", "-")}-AdminAlertsTopic"
}

resource "aws_sns_topic_subscription" "admin_email_sub" {
  topic_arn = aws_sns_topic.admin_alerts.arn
  protocol  = "email"
  endpoint  = var.admin_email
}


############################################
# CloudWatch Dashboard & Alarms            #
############################################

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${replace(var.project_name, " ", "-")}-Infrastructure-Health"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", "InstanceId", aws_instance.web_server.id],
          ]
          view     = "timeSeries"
          stacked  = false
          region   = var.aws_region
          stat     = "Average"
          period   = 300
          title    = "EC2 CPU Utilization"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/S3", "BucketSizeBytes", "BucketName", aws_s3_bucket.monitor_bucket.id, "StorageType", "StandardStorage"],
          ]
          view     = "timeSeries"
          stacked  = false
          region   = var.aws_region
          stat     = "Average"
          period   = 3600
          title    = "S3 Bucket Storage Usage"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/RDS", "FreeStorageSpace", "DBInstanceIdentifier", aws_db_instance.main.id],
          ]
          view     = "timeSeries"
          stacked  = false
          region   = var.aws_region
          stat     = "Average"
          period   = 300
          title    = "RDS Free Storage Space"
        }
      },
    ]
  })
}

resource "aws_cloudwatch_metric_alarm" "high_cpu_alarm" {
  alarm_name          = "${replace(var.project_name, " ", "-")}-HighCPU-WebServer-Alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This alarm monitors EC2 CPU utilization"
  alarm_actions       = [aws_sns_topic.admin_alerts.arn]
  ok_actions          = [aws_sns_topic.admin_alerts.arn]

  dimensions = {
    InstanceId = aws_instance.web_server.id
  }
}


############################################
# Lambda Function for Network Test         #
############################################

# Zip the Python code for Lambda deployment
# This resource creates the zip file at the specified output_path
resource "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda/network_tester.py"
  output_path = "${path.module}/../lambda/${replace(var.project_name, " ", "-")}-network_tester.zip" # Output zip with project name
}

# Upload the zip file to S3
# IMPORTANT FIX: Use archive_file.lambda_zip.output_base64sha256 for etag
resource "aws_s3_object" "lambda_code" {
  bucket = aws_s3_bucket.monitor_bucket.id
  key    = "${replace(var.project_name, " ", "-")}-network_tester.zip"
  source = archive_file.lambda_zip.output_path
  etag   = archive_file.lambda_zip.output_base64sha256 # Use the hash directly from archive_file

  depends_on = [archive_file.lambda_zip] # Explicit dependency
}

resource "aws_iam_role" "lambda_network_tester_role" {
  name = "${replace(var.project_name, " ", "-")}-LambdaNetworkTesterRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "${var.project_name}-LambdaNetworkTesterRole"
  }
}

resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
  role       = aws_iam_role.lambda_network_tester_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_policy" "sns_publish_policy" {
  name        = "${replace(var.project_name, " ", "-")}-SNSPublishPolicy"
  description = "Allows Lambda to publish messages to the SNS topic"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = "sns:Publish",
        Resource = aws_sns_topic.admin_alerts.arn,
      },
    ],
  })
}

resource "aws_iam_role_policy_attachment" "sns_publish_attach" {
  role       = aws_iam_role.lambda_network_tester_role.name
  policy_arn = aws_iam_policy.sns_publish_policy.arn
}

resource "aws_lambda_function" "network_tester" {
  function_name    = "${replace(var.project_name, " ", "-")}-NetworkTester"
  s3_bucket        = aws_s3_bucket.monitor_bucket.id
  s3_key           = aws_s3_object.lambda_code.key
  handler          = "network_tester.lambda_handler"
  runtime          = "python3.9" # Or your preferred Python 3.x version
  role             = aws_iam_role.lambda_network_tester_role.arn
  timeout          = 30
  memory_size      = 128
  # IMPORTANT FIX: Use archive_file.lambda_zip.output_base64sha256 for source_code_hash
  source_code_hash = archive_file.lambda_zip.output_base64sha256

  vpc_config {
    security_group_ids = [aws_security_group.web_server_sg.id] # Using web server SG for simplicity
    subnet_ids         = [for s in aws_subnet.private : s.id]
  }

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.admin_alerts.arn
    }
  }

  tags = {
    Name = "${var.project_name}-NetworkTester"
  }

  depends_on = [
    aws_s3_object.lambda_code # Ensure the zip is uploaded to S3 first
  ]
}

resource "aws_cloudwatch_event_rule" "network_tester_schedule" {
  name                = "${replace(var.project_name, " ", "-")}-NetworkTesterSchedule"
  description         = "Trigger NetworkTester Lambda every hour"
  schedule_expression = "rate(1 hour)"
}

resource "aws_cloudwatch_event_target" "network_tester_target" {
  rule      = aws_cloudwatch_event_rule.network_tester_schedule.name
  arn       = aws_lambda_function.network_tester.arn
}

resource "aws_lambda_permission" "allow_cloudwatch_to_invoke_network_tester" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.network_tester.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.network_tester_schedule.arn
}


############################################
# Outputs (to easily retrieve info)        #
############################################

output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

output "ec2_public_ip" {
  description = "Public IP of the EC2 Web Server"
  value       = aws_instance.web_server.public_ip
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.monitor_bucket.id
}

output "rds_endpoint" {
  description = "RDS instance endpoint address"
  value       = aws_db_instance.main.address
  sensitive   = true
}

output "cloudwatch_dashboard_url" {
  description = "URL to the CloudWatch Dashboard"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}