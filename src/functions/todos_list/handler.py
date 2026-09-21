"""GET /api/{v}/todos  —  list every todo.  (auth: jwt)

USE CASE
--------
Read-only, so it just opens the connection, copies the rows out, and lets
the `with` block close (rewrite) the file unchanged. No retry needed: a
read has nothing to lose a race over.
"""

import qe_common as qe
import csv_store


def handler(event, context):
    version = qe.api_version(event)
    if version not in qe.SUPPORTED_VERSIONS:
        return qe.error(400, f"unsupported api version: {version}")

    with csv_store.connect() as rows:
        todos = [qe.todo_out(r) for r in rows]

    return qe.respond(200, {"todos": todos})
