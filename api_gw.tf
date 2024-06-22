
resource "aws_apigatewayv2_api" "main-api" {
 	name          = "main-api"
	protocol_type = "HTTP"
	target        = aws_lambda_function.lambda_fcn.arn
	cors_configuration {
		allow_origins = ["*"]
	}
}

resource "aws_apigatewayv2_integration" "integration" {
  api_id            = aws_apigatewayv2_api.main-api.id
  integration_type  = "AWS_PROXY"
  integration_method = "POST"
  integration_uri = aws_lambda_function.lambda_fcn.invoke_arn
}

resource "aws_apigatewayv2_route" "visitcount" {
  api_id    = aws_apigatewayv2_api.main-api.id
  route_key = "POST /visitcount"

  target = "integrations/${aws_apigatewayv2_integration.integration.id}"
}


# Lambda
resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_fcn.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn =  "${aws_apigatewayv2_api.main-api.execution_arn}/*/*"
}

data "archive_file" "lambda_package" {
    type = "zip"
    source_dir = "${var.lambda_path}/src/backend"
    output_path = "${var.lambda_path}/lambda.zip"
}


resource "aws_lambda_function" "lambda_fcn" {
  filename      = "lambda.zip"
  function_name = "mylambda"
  role          = aws_iam_role.lambda_role.arn
  handler       = "app.lambda_handler"
  runtime       = "python3.9"

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
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  ]
  
  inline_policy {
    name = "ddbreadwrite"
    policy = data.aws_iam_policy_document.ddbreadwrite.json
  }
}


resource "aws_apigatewayv2_deployment" "prod" {
  api_id      = aws_apigatewayv2_api.main-api.id
  description = "prod deployment"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_apigatewayv2_stage" "prod-stage" {
  api_id = aws_apigatewayv2_api.main-api.id
  name   = "prod-stage"
}
















