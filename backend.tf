terraform {
  backend "s3" {
    bucket = "depiproject-tfstate "
    key    = "path/to/my/key"
    region = "eu-north-1"
  }
}
