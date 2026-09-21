# locals.tf
# ---------------------------------------------------------------------------
# USE CASE: the one place you edit to add an endpoint.
#
# `local.functions` is the endpoint table. One entry = one source directory
# = one Lambda = one API Gateway route. main.tf and api.tf both loop over it,
# so routing is declared here once and never re-implemented in Python.
# ---------------------------------------------------------------------------

locals {
  name_prefix = "${var.project}-${var.environment}" # e.g. qe-api-dev
  build_dir   = "${path.root}/.build"               # generated zips, gitignored

  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  }

  # Resource names handed to the handlers as environment variables.
  lambda_environment = {
    TODOS_BUCKET = module.storage.bucket_name
  }

  # THE ENDPOINT TABLE.
  #   key   -> must match a directory under src/functions/
  #   route -> API Gateway route key; null means no HTTP route (queue worker)
  #   auth  -> "jwt" tenant-scoped end-user route
  #            "iam" SigV4, for internal service-to-service callers only
  functions = {
    todos_create = { route = "POST /api/{v}/todos", auth = "jwt" }
    todos_list   = { route = "GET /api/{v}/todos", auth = "jwt" }
    todo_get     = { route = "GET /api/{v}/todos/{id}", auth = "jwt" }
    todo_update  = { route = "PUT /api/{v}/todos/{id}", auth = "jwt" }
    todo_delete  = { route = "DELETE /api/{v}/todos/{id}", auth = "jwt" }
  }

  # Only entries with a route become API Gateway routes.
  http_functions = { for k, f in local.functions : k => f if f.route != null }
}
