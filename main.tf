terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
  profile = "iamadmin"
}

 
data "aws_secretsmanager_secret" "ssl-cert" {
    name = "resume-ssl-certificate-arn"
}

data "aws_secretsmanager_secret" "hosted-zone-id" {
    name = "r53-hosted-zone-id-domain"
}

data "aws_secretsmanager_secret_version" "cert-arn" {
    secret_id = data.aws_secretsmanager_secret.ssl-cert.id
}

data "aws_secretsmanager_secret_version" "hz-id" {
    secret_id = data.aws_secretsmanager_secret.hosted-zone-id.id
}

locals {
    s3_bucket_name = "static-resume-webpage-bucket"
    domain = "resume.adelani.xyz"
    hosted_zone_id = jsondecode(data.aws_secretsmanager_secret_version.hz-id.secret_string)["hosted-zone-id"]
    cert_arn = jsondecode(data.aws_secretsmanager_secret_version.cert-arn.secret_string)["resume-ssl-certificate-arn"]
}



terraform {
  backend "s3" {
    bucket  = "tfstate-bucket-resume-project"
    key     = "build/terraform.tfstate"
    region  = "us-east-1"
  }
}

resource "aws_s3_bucket" "static-resume-website" {
  bucket = local.s3_bucket_name
  tags = {
    Name = "Project files"
  }
}

resource "aws_cloudfront_origin_access_control" "main-oac" {
    name = "s3-cloudfront-oac-main"
    origin_access_control_origin_type = "s3"
    signing_behavior = "always"
    signing_protocol = "sigv4"
}

resource "aws_cloudfront_distribution" "main" {
    
    origin {
      origin_access_control_id = aws_cloudfront_origin_access_control.main-oac.id
      domain_name = aws_s3_bucket.static-resume-website.bucket_regional_domain_name
      origin_id = aws_s3_bucket.static-resume-website.bucket
    }
 #
    enabled = true
    aliases = [local.domain]
    default_root_object = "index.html"
    is_ipv6_enabled = true
    wait_for_deployment = true

    default_cache_behavior {
      allowed_methods = ["GET","HEAD","OPTIONS"]
      cached_methods = ["GET","HEAD","OPTIONS"]
      cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"
      target_origin_id = aws_s3_bucket.static-resume-website.bucket
      viewer_protocol_policy = "redirect-to-https"
    }

    restrictions {
      geo_restriction {
        restriction_type = "none"
      }
    }

    viewer_certificate {
      acm_certificate_arn = local.cert_arn
      minimum_protocol_version = "TLSv1.2_2021"
      ssl_support_method = "sni-only"
    }
}


data "aws_iam_policy_document" "cloudfront_oac_access" {
  statement {
    principals {
      identifiers = ["cloudfront.amazonaws.com"]
      type = "Service"
    }
    actions = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.static-resume-website.arn}/*"]

    condition {
      test = "StringEquals"
      values = [aws_cloudfront_distribution.main.arn]
      variable = "AWS:SourceArn"
    }
  }
}

resource "aws_s3_bucket_policy" "access_policy" {
    bucket = aws_s3_bucket.static-resume-website.id
    policy = data.aws_iam_policy_document.cloudfront_oac_access.json
}

resource "aws_route53_record" "domain-record" {
    name = local.domain
    type = "A"
    zone_id = local.hosted_zone_id

    alias {
      evaluate_target_health = false
      name = aws_cloudfront_distribution.main.domain_name
      zone_id = aws_cloudfront_distribution.main.hosted_zone_id
    }
}

