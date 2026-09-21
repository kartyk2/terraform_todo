"""Helpers shared by every todo-app Lambda.

USE CASE
--------
Packaged as a Lambda layer (see layer.tf). It lives under `python/` because
that is the directory the Lambda Python runtime puts on sys.path, which is
why handlers can simply `import qe_common`.

Put something here only when a second handler needs it.
"""

import json
import uuid
from datetime import datetime, timezone

# Versions this API answers to. See the version-maintenance notes in api.tf:
# the {v} path segment is a wildcard, so the ONLY thing rejecting an unknown
# version is this list plus the check each handler makes against it.
SUPPORTED_VERSIONS = ("v1",)


def api_version(event):
    """The resolved {v} path segment, e.g. "v1". None if the route had none."""
    return (event.get("pathParameters") or {}).get("v")


def path_param(event, name):
    return (event.get("pathParameters") or {}).get(name)


def now():
    """UTC timestamp, ISO-8601."""
    return datetime.now(timezone.utc).isoformat()


def new_id(prefix):
    """Short, prefixed, URL-safe identifier (todo_a1b2c3d4e5f6)."""
    return f"{prefix}_{uuid.uuid4().hex[:12]}"


def respond(status, body):
    """API Gateway HTTP API (payload format 2.0) response envelope.
    body=None (used for 204) sends an empty body, not the literal "null"."""
    return {
        "statusCode": status,
        "headers": {"content-type": "application/json"},
        "body": "" if body is None else json.dumps(body),
    }


def error(status, message):
    return respond(status, {"error": message})


def json_body(event):
    """Parse the request body. Returns None if it is not valid JSON."""
    try:
        return json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        return None


def todo_out(row):
    """CSV rows are all strings; this is the one place "done" becomes a
    real bool again before a row goes out over the API."""
    return {
        "id": row["id"],
        "title": row["title"],
        "done": row.get("done") == "true",
        "created_at": row.get("created_at"),
        "updated_at": row.get("updated_at"),
    }
