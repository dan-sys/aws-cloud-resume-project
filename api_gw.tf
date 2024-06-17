


resource "aws_api_gateway_rest_api" "main_api" {
    name = "main-api"

    endpoint_configuration {
      types = [ "REGIONAL" ]
    }
}

resource "aws_api_gateway_resource" "root-resource" {
  parent_id   = aws_api_gateway_rest_api.main_api.root_resource_id
  path_part   = "visitcount"
  rest_api_id = aws_api_gateway_rest_api.main_api.id
}

resource "aws_api_gateway_method" "api-method" {
  authorization = "NONE"
  http_method   = "GET"
  resource_id   = aws_api_gateway_resource.root-resource.id
  rest_api_id   = aws_api_gateway_rest_api.main_api.id
}

resource "aws_api_gateway_integration" "lambda_integration" {
  http_method = aws_api_gateway_method.api-method.http_method
  resource_id = aws_api_gateway_resource.root-resource.id
  rest_api_id = aws_api_gateway_rest_api.main_api.id
  integration_http_method = "GET"
  type        = "AWS_PROXY"
  uri = aws_lambda_function.lambda_fcn.invoke_arn
}

# Lambda
resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_fcn.function_name
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn =  "${aws_api_gateway_rest_api.main_api.execution_arn}/*/*/*"
  #source_arn = "arn:aws:execute-api:${var.myregion}:${var.accountId}:${aws_api_gateway_rest_api.main_api.id}/*/${aws_api_gateway_method.api-method.http_method}${aws_api_gateway_resource.root-resource.path}"
}

data "archive_file" "lambda_package" {
    type = "zip"
    #source_dir  = "${path.module}/src/backend"
    source_dir = "${var.lambda_path}/src/backend"
    output_path = "${var.lambda_path}/lambda.zip"
}


resource "aws_lambda_function" "lambda_fcn" {
  filename      = "lambda.zip"
  function_name = "mylambda"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda/app.lambda_handler"
  runtime       = "python3.9"

  #source_code_hash = filebase64sha256("lambda.zip")
  source_code_hash = data.archive_file.lambda_package.output_base64sha256
}

# IAM
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "lambda_role" {
  name               = "myrole"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  inline_policy {
    name = "ddbreadwrite"
    policy = data.aws_iam_policy_document.ddbreadwrite.json
  }
}


resource "aws_api_gateway_deployment" "deployment-main" {
  rest_api_id = aws_api_gateway_rest_api.main_api.id

  triggers = {
    redeployment = sha1(jsonencode(aws_api_gateway_rest_api.main_api.body))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.deployment-main.id
  rest_api_id   = aws_api_gateway_rest_api.main_api.id
  stage_name    = "prod"
}
















