"""GET /api/{v}/todos/{id}  —  fetch one todo.  (auth: jwt)"""

import qe_common as qe
import csv_store


def handler(event, context):
    version = qe.api_version(event)
    if version not in qe.SUPPORTED_VERSIONS:
        return qe.error(400, f"unsupported api version: {version}")

    todo_id = qe.path_param(event, "id")

    with csv_store.connect() as rows:
        match = next((r for r in rows if r["id"] == todo_id), None)

    if match is None:
        return qe.error(404, "todo not found")

    return qe.respond(200, qe.todo_out(match))
