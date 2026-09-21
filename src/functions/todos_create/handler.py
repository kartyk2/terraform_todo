"""POST /api/{v}/todos  —  create a todo.  (auth: jwt)

USE CASE
--------
Appends one row to todos.csv. Uses csv_store.retry() because appending is a
mutation: if another create/update/delete wins the write race first, this
one must redo the append against the fresh file, not silently vanish.
"""

import qe_common as qe
import csv_store


def handler(event, context):
    version = qe.api_version(event)
    if version not in qe.SUPPORTED_VERSIONS:
        return qe.error(400, f"unsupported api version: {version}")

    body = qe.json_body(event)
    if body is None:
        return qe.error(400, "body is not valid json")

    title = (body.get("title") or "").strip()
    if not title:
        return qe.error(400, "title is required")

    todo_id = qe.new_id("todo")
    now = qe.now()
    row = {
        "id": todo_id,
        "title": title,
        "done": "false",
        "created_at": now,
        "updated_at": now,
    }

    def append(rows):
        rows.append(row)
        return row

    try:
        created = csv_store.retry(append)
    except csv_store.StaleWriteError:
        return qe.error(409, "too many concurrent writes, try again")

    return qe.respond(201, qe.todo_out(created))
