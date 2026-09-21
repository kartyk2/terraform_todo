"""PUT /api/{v}/todos/{id}  —  rename and/or toggle done.  (auth: jwt)

USE CASE
--------
Mutates one row in place. csv_store.retry() re-finds the row and reapplies
the same edit if a concurrent write got there first — safe to rerun because
it always sets fields from the request body, never increments/toggles
relative to what it last read.
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

    todo_id = qe.path_param(event, "id")

    def update(rows):
        row = next((r for r in rows if r["id"] == todo_id), None)
        if row is None:
            return None
        if "title" in body:
            title = (body.get("title") or "").strip()
            if not title:
                raise ValueError("title cannot be empty")
            row["title"] = title
        if "done" in body:
            row["done"] = "true" if body.get("done") else "false"
        row["updated_at"] = qe.now()
        return row

    try:
        updated = csv_store.retry(update)
    except csv_store.StaleWriteError:
        return qe.error(409, "too many concurrent writes, try again")
    except ValueError as exc:
        return qe.error(400, str(exc))

    if updated is None:
        return qe.error(404, "todo not found")

    return qe.respond(200, qe.todo_out(updated))
