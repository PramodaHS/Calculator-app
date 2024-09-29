provider "aws" {
  region = "ap-south-1" # Mumbai region
}

# S3 Bucket
resource "aws_s3_bucket" "calci_app_bucket" {
  bucket = "new-bucket-calci" # Updated S3 bucket name
  acl    = "private"

  tags = {
    Name        = "new-bucket-calci"
    Environment = "Production"
  }
}

# IAM Role for CodeDeploy
resource "aws_iam_role" "code_deploy_role" {
  name               = "ec2-code-deploy" # Updated IAM role name
  assume_role_policy = data.aws_iam_policy_document.code_deploy_assume_role_policy.json
}

data "aws_iam_policy_document" "code_deploy_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codedeploy.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "code_deploy_policy_attachment" {
  role       = aws_iam_role.code_deploy_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
}

# EC2 Instance
resource "aws_instance" "calci_app_instance" {
  ami           = "ami-ami-0522ab6e1ddcc7055" # You might want to check the latest AMI for Mumbai
  instance_type = "t2.micro"
  
  iam_instance_profile = aws_iam_instance_profile.code_deploy_instance_profile.name

  tags = {
    Name = "calci-app-ec2" # Updated EC2 instance name
  }

  provisioner "file" {
    source      = "Calculator-app.zip" # Local path to your app ZIP file
    destination = "/tmp/calci-app-build-1.zip" # Updated destination name
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum update -y",
      "sudo yum install -y ruby",
      "sudo yum install -y wget",
      "wget https://s3.amazonaws.com/aws-codedeploy-ap-south-1/latest/install",
      "chmod +x ./install",
      "./install auto",
      "sudo service codedeploy-agent start",
      "aws s3 cp /tmp/calci-app-build-1.zip s3://${aws_s3_bucket.calci_app_bucket.bucket}/"
    ]
  }
}

resource "aws_iam_instance_profile" "code_deploy_instance_profile" {
  name = "CodeDeployInstanceProfile"
  role = aws_iam_role.code_deploy_role.name
}

# CodeDeploy Application
resource "aws_codedeploy_app" "calci_app" {
  name = "CalciApp"
}

# CodeDeploy Deployment Group
resource "aws_codedeploy_deployment_group" "calci_app_deployment_group" {
  app_name               = aws_codedeploy_app.calci_app.name
  deployment_group_name  = "calculator-app-dgp" # Updated CodeDeploy deployment group name
  service_role_arn       = aws_iam_role.code_deploy_role.arn

  deployment_style {
    deployment_type = "IN_PLACE"
    ignore_app_stop_failures = false
  }

  ec2_tag_filter {
    key   = "Name"
    type  = "KEY_AND_VALUE"
    value = aws_instance.calci_app_instance.tags["Name"]
  }
}