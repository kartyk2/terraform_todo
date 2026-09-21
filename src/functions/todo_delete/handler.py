"""DELETE /api/{v}/todos/{id}  —  remove a todo.  (auth: jwt)

USE CASE
--------
csv_store.retry() re-finds the row by id and removes it again on a lost
write race. If it's already gone by the time this retries (deleted twice
concurrently), that's a 404, not an error — delete is idempotent.
"""

import qe_common as qe
import csv_store


def handler(event, context):
    version = qe.api_version(event)
    if version not in qe.SUPPORTED_VERSIONS:
        return qe.error(400, f"unsupported api version: {version}")

    todo_id = qe.path_param(event, "id")

    def remove(rows):
        for i, row in enumerate(rows):
            if row["id"] == todo_id:
                del rows[i]
                return True
        return False

    try:
        found = csv_store.retry(remove)
    except csv_store.StaleWriteError:
        return qe.error(409, "too many concurrent writes, try again")

    if not found:
        return qe.error(404, "todo not found")

    return qe.respond(204, None)
