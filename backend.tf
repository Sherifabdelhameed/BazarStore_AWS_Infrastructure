terraform {
  backend "s3" {
    bucket = "depiproject-tfstate"
    key    = "terraform.tfstate"
    region = "eu-north-1"
  }
}
