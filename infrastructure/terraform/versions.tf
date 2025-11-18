# Terraform Version Requirements
# NuDocker HTCondor Infrastructure

terraform {
  required_version = ">= 1.0"

  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.52"
    }
  }

  # Uncomment to use remote backend
  # backend "s3" {
  #   bucket = "terraform-state-nudocker"
  #   key    = "htcondor/terraform.tfstate"
  #   region = "us-east-1"
  # }
}
