provider "aws" {
    region = "ap-south-1"
}

terraform {
    backend "s3" {
        key = "global/s3/terraform.tfstate"
    }
}

resource "aws_s3_bucket" "terraform_state" {
    bucket = "leaning-projects-1"
# Prevent accidental deletion of this S3 bucket
    lifecycle {
    prevent_destroy = true
    }
# Enable versioning so we can see the full revision history of state files
    versioning {
        enabled = true
    }
# Enable server-side encryption by default
    server_side_encryption_configuration {
        rule {
            apply_server_side_encryption_by_default {
            sse_algorithm = "AES256"
            }
        }
    }
}
#dynamoDB is distributed k-v pair store that supports consistent read/write. 
resource "aws_dynamodb_table" "terraform_locks" {
    name = "learning-projects-locks"
    billing_mode = "PAY_PER_REQUEST"
    hash_key = "LockID" 
    attribute { 
        name = "LockID"
        type = "S"
    }
}