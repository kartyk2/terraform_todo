# api.tf
# ---------------------------------------------------------------------------
# USE CASE: the public front door. An API Gateway HTTP API with one route per
# entry in local.http_functions, each pointing at its own Lambda.
#
# There is no dispatcher in application code: a request that matches no route
# is rejected with a 404 by API Gateway before any function is invoked.
#
# ---------------------------------------------------------------------------
# HOW API VERSION MAINTENANCE WORKS
# ---------------------------------------------------------------------------
# Every route key contains a literal `{v}` segment, e.g.
#
#     POST /api/{v}/exe
#
# `{v}` is a real API Gateway path parameter, not a hardcoded "v1". That has
# three consequences you need to know:
#
#   1. ONE route serves ALL versions. /api/v1/exe and /api/v2/exe both match
#      the same route and invoke the same Lambda. You do not deploy new
#      infrastructure to ship a new version.
#
#   2. The version is data, not routing. The handler reads it with
#      qe_common.api_version(event) and branches on it. Version-specific
#      behaviour lives in Python, where it can be tested, not in Terraform.
#
#   3. Nothing here validates the version. /api/banana/exe reaches the
#      handler. Handlers are expected to reject unknown versions with a 400 —
#      see the check in src/functions/exe/handler.py.
#
# When you need a genuinely incompatible v2 of a single endpoint, the cheap
# path is a version branch inside that one handler. Only split into a
# separate function + route key (e.g. "POST /api/v2/exe") when the two
# versions no longer share meaningful code — at that point the dedicated
# route takes precedence over the {v} wildcard for that exact path.
# ---------------------------------------------------------------------------

resource "aws_apigatewayv2_api" "this" {
  name          = local.name_prefix
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"] # tighten to your front-end origins before prod
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_headers = ["authorization", "content-type", "x-tenant-id"]
    max_age       = 300
  }
}

# Tenant isolation starts here: the authorizer validates the caller's token
# and forwards its claims (including tenant_id) to the handler.
# Created only when an issuer is configured, so dev can run without an IdP.
resource "aws_apigatewayv2_authorizer" "jwt" {
  count = var.jwt_issuer == null ? 0 : 1

  api_id           = aws_apigatewayv2_api.this.id
  name             = "${local.name_prefix}-tenant-jwt"
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]

  jwt_configuration {
    issuer   = var.jwt_issuer
    audience = var.jwt_audience
  }
}

# AWS_PROXY hands the raw request to Lambda in payload format 2.0 and takes
# the function's {statusCode, headers, body} back as the HTTP response.
resource "aws_apigatewayv2_integration" "this" {
  for_each = local.http_functions

  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_uri        = module.lambda[each.key].invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
  timeout_milliseconds   = 29000 # API Gateway's hard ceiling
}

resource "aws_apigatewayv2_route" "this" {
  for_each = local.http_functions

  api_id    = aws_apigatewayv2_api.this.id
  route_key = each.value.route
  target    = "integrations/${aws_apigatewayv2_integration.this[each.key].id}"

  # "iam" -> always SigV4. "jwt" -> JWT when an issuer exists, otherwise open,
  # because a dev stack with no IdP would otherwise be unreachable.
  authorization_type = (
    each.value.auth == "iam" ? "AWS_IAM" :
    each.value.auth == "jwt" && var.jwt_issuer != null ? "JWT" : "NONE"
  )

  authorizer_id = (
    each.value.auth == "jwt" && var.jwt_issuer != null
    ? aws_apigatewayv2_authorizer.jwt[0].id
    : null
  )
}

# Without this the integration exists but API Gateway is not permitted to
# call the function. One statement per function, scoped to this API.
resource "aws_lambda_permission" "invoke" {
  for_each = local.http_functions

  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda[each.key].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}

resource "aws_cloudwatch_log_group" "api_access" {
  name              = "/aws/apigateway/${local.name_prefix}"
  retention_in_days = var.log_retention_days
}

# $default as the stage name keeps the invoke URL free of a stage prefix.
resource "aws_apigatewayv2_stage" "this" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_access.arn
    format = jsonencode({
      requestId = "$context.requestId"
      routeKey  = "$context.routeKey"
      path      = "$context.path" # includes the resolved {v}, so you can see version mix
      status    = "$context.status"
      latencyMs = "$context.responseLatency"
      tenantId  = "$context.authorizer.claims.tenant_id"
    })
  }
}
