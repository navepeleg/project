terraform {
  backend "s3" {
    bucket          = "nave-bootcamp-project"
    key             = "terraform-state/terraform.tfstate"
    region          = "eu-west-1"
  }
}