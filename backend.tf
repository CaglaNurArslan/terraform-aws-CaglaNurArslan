terraform {
  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "ZiyotekFALL22arslan"
    workspaces {
      name = "terraform-aws-CaglaNurArslan"
    }
  }
}