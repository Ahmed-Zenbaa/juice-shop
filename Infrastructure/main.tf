provider "aws" {
  region = "us-east-1"
}

# ----------------------
# CloudTrail enabled
# ----------------------
resource "aws_cloudtrail" "good_trail" {
  name                          = "secure-trail"
  s3_bucket_name                = "my-secure-logs-bucket-123456"
  include_global_service_events = true
}

# ----------------------
# S3 Conf
# ----------------------
resource "aws_s3_bucket" "mixed_bucket" {
  bucket = "mixed-security-bucket-123456"

  tags = {
    Name = "MixedBucket"
  }
}

# encryption enabled
resource "aws_s3_bucket_server_side_encryption_configuration" "good_enc" {
  bucket = aws_s3_bucket.mixed_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# still publicly accessible
resource "aws_s3_bucket_public_access_block" "bad_public" {
  bucket = aws_s3_bucket.mixed_bucket.id

  block_public_acls   = false
  block_public_policy = false
}

# ----------------------
# IAM Conf
# ----------------------
resource "aws_iam_role" "good_role" {
  name = "ec2-readonly-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

# overly permissive policy
resource "aws_iam_policy" "bad_policy" {
  name = "too-permissive"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = "*",
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "attach_bad" {
  role       = aws_iam_role.good_role.name
  policy_arn = aws_iam_policy.bad_policy.arn
}

# ----------------------
# Security Group Conf
# ----------------------
resource "aws_security_group" "mixed_sg" {
  name = "mixed-sg"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ----------------------
# EC2 conf
# ----------------------
resource "aws_instance" "mixed_ec2" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t3.micro"

  vpc_security_group_ids = [aws_security_group.mixed_sg.id]

  associate_public_ip_address = true

  iam_instance_profile = aws_iam_role.good_role.name

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    encrypted = true
  }

  tags = {
    Name = "MixedInstance"
  }
}

# ----------------------
# RDS Conf
# ----------------------
resource "aws_db_instance" "bad_rds" {
  identifier        = "mixed-db"
  engine            = "mysql"
  instance_class    = "db.t3.micro"
  allocated_storage = 20

  username = "admin"
  password = "weakpassword"

  publicly_accessible = true
  storage_encrypted   = false

  skip_final_snapshot = true
}

# ----------------------
# EBS Volume Conf
# ----------------------
resource "aws_ebs_volume" "secure_volume" {
  availability_zone = "us-east-1a"
  size              = 10

  encrypted = true

  tags = {
    Name = "SecureVolume"
  }
}
