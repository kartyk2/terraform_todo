# qe_api — infrastructure

A TODO app on AWS: **API Gateway HTTP API, one Lambda per endpoint, and a
single CSV file in S3 as the entire database.** No RDS, no DynamoDB — cheap
by design, and small enough to read end to end in one sitting.

## Layout

    versions.tf      provider pins + how version maintenance works
    providers.tf     AWS provider, default tags
    backend.tf       state location (local today)
    variables.tf     inputs, supplied by envs/*.tfvars
    locals.tf        >> THE ENDPOINT TABLE — edit this to add a route <<
    iam.tf           the shared Lambda execution role, scoped to todos.csv
    layer.tf         packages src/shared/ as the qe_common + csv_store layer
    main.tf          creates the storage bucket + one Lambda per endpoint
    api.tf           HTTP API, JWT authorizer, routes + how API versioning works
    outputs.tf       base URL, bucket name, role ARN, route map
    envs/dev.tfvars  dev inputs
    modules/
      lambda/        the reusable module: zip + log group + function
      storage/       the S3 bucket holding todos.csv
    src/
      shared/python/
        qe_common.py   response envelope, tenant/version helpers
        csv_store.py   the S3-CSV "connection" — see below
      functions/<name>/handler.py   one directory per endpoint

## The storage model

`todos.csv` in S3 IS the database. There is no server holding it open:
every request is its own connection, in the literal sense the word implies
for a file —

    with csv_store.connect() as rows:   # OPEN:  GetObject, parse CSV, keep ETag
        ...                             # read or mutate `rows` in place
                                         # CLOSE: serialize, PutObject

and the file is fully closed (written back, or discarded on an exception)
before the handler returns. Nothing is held open between requests or across
Lambda invocations.

Two Lambdas can still race to write at the same moment, so every `PutObject`
is conditioned on the ETag read at open time (`If-Match`, or
`If-None-Match: "*"` for the first write ever). A losing writer gets S3's
412 back as `csv_store.StaleWriteError`. Mutating handlers don't catch that
themselves — they call `csv_store.retry(fn)`, which reopens the file and
reruns `fn` against the fresh copy, up to 3 times, before giving the caller
a 409.

This is a full-file read-modify-write on every write, so it does not scale
past occasional concurrent writers. That's the trade this app deliberately
makes for a cheap, readable data store — see `csv_store.py`'s module
docstring for the exact reasoning and when to graduate to DynamoDB instead.

## Endpoints

| Route | Function | Auth |
| --- | --- | --- |
| `POST /api/{v}/todos` | `todos_create` | JWT (tenant) |
| `GET /api/{v}/todos` | `todos_list` | JWT (tenant) |
| `GET /api/{v}/todos/{id}` | `todo_get` | JWT (tenant) |
| `PUT /api/{v}/todos/{id}` | `todo_update` | JWT (tenant) |
| `DELETE /api/{v}/todos/{id}` | `todo_delete` | JWT (tenant) |

A todo is `{id, title, done, created_at, updated_at}`.

## Adding an endpoint

1. `mkdir src/functions/<name>` and write `handler.py` with a `handler(event, context)`.
2. Add one line to `local.functions` in `locals.tf`.
3. `terraform apply -var-file=envs/dev.tfvars`.

`route = null` gives you a Lambda with no HTTP route (a queue worker).

## API versioning

`{v}` is a real path parameter, so `/api/v1/todos` and `/api/v2/todos` hit
the same route and the same Lambda — new versions need no new
infrastructure. API Gateway does **not** validate it; handlers check the
resolved value against `qe_common.SUPPORTED_VERSIONS` and return 400. Full
reasoning is in the header comment of [api.tf](api.tf).

Provider/lockfile version maintenance is documented in [versions.tf](versions.tf).

## Usage

```bash
terraform init
terraform plan -var-file=envs/dev.tfvars
```

```bash
terraform apply -var-file=envs/dev.tfvars
```

In dev `jwt_issuer` is null, so no authorizer is created, JWT routes deploy
**open**, and handlers fall back to an `X-Tenant-Id` header. Local testing
only — set a real issuer for anything else.

```bash
curl -X POST "$API/api/v1/todos" -H 'content-type: application/json' \
  -d '{"title": "ship the demo"}'

curl "$API/api/v1/todos"
```

## Not done yet

State is local (see `backend.tf`) and there is only a `dev` tfvars file.
Tenant scoping is stubbed in `qe_common.py` — every request currently reads
and writes the same `todos.csv`, with no per-tenant prefix. Add that before
running more than one tenant against this stack.
