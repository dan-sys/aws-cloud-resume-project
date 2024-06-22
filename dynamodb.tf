
resource "aws_dynamodb_table_item" "item-insert" {
  table_name = aws_dynamodb_table.counter-table.name
  hash_key   = aws_dynamodb_table.counter-table.hash_key

  item = <<ITEM
{
  "counter": {"N": "0"}
}
ITEM
}

resource "aws_dynamodb_table" "counter-table" {
    name = "counter-table"
    billing_mode = "PAY_PER_REQUEST"
    hash_key = "counter"

    attribute {
      name = "counter"
      type = "N"
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
