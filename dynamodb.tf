

resource "aws_dynamodb_table" "counter-table" {
    name = "counter-table"
    billing_mode = "PROVISIONED"
    hash_key = "counter"

    attribute {
      name = "counter"
      type = S
    }
}

data "aws_iam_policy_document" "ddbreadwrite" {
  statement {
    sid       = "ddbreadwrite"
    effect    = "Allow"
    actions   = ["dynamodb:Scan", "dynamodb:PutItem", "dynamodb:GetItem", "dynamodb:UpdateItem"]
    resources = ["*"]
  }
}
