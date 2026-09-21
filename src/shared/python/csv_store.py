"""S3-backed CSV "connection" for the todos table.

USE CASE
--------
There is no database. todos.csv in S3 IS the database, and this module is
its driver. Every handler does exactly this:

    with csv_store.connect() as todos:
        # todos is a list[dict], the whole table, in memory
        ...                  # read it, or mutate/append/remove a row
        # nothing is written to S3 until the block exits

`connect()` is a context manager that:
  1. OPENS the connection  -> GetObject, parse CSV into list[dict], keep ETag
  2. yields the rows for the handler to read/mutate in place
  3. CLOSES the connection -> serialize back to CSV, PutObject conditioned
     on that ETag (If-Match, or If-None-Match: "*" if the object didn't
     exist yet), so the write only lands if nobody else changed the object
     since step 1.

One `with` block = one open + one close. It does NOT retry internally —
a generator-based context manager can only run the caller's code once per
`with`, so retrying a lost write race means re-running the caller's
mutation against a fresh read, which has to happen at the call site. See
`retry()` below for that.

This is a full-file read-modify-write, not a database — the right amount of
engineering for "cheap CSV on S3". The moment writes collide often enough
that `retry()` is routinely exhausted, that's the signal to move to
DynamoDB (see the README).
"""

import csv
import io
import os
import time
from contextlib import contextmanager

import boto3
from botocore.exceptions import ClientError

BUCKET = os.environ.get("TODOS_BUCKET", "")
KEY = "todos.csv"
FIELDS = ["id", "title", "done", "created_at", "updated_at"]

_s3 = boto3.client("s3")


class StaleWriteError(Exception):
    """The CSV changed between open and close; this attempt was not written."""


def _open():
    """Read + parse the CSV. Returns (rows, etag). etag is None if the
    object does not exist yet — the first write creates it."""
    try:
        obj = _s3.get_object(Bucket=BUCKET, Key=KEY)
    except ClientError as exc:
        if exc.response["Error"]["Code"] in ("NoSuchKey", "404"):
            return [], None
        raise

    body = obj["Body"].read().decode("utf-8")
    rows = list(csv.DictReader(io.StringIO(body)))
    return rows, obj["ETag"]


def _close(rows, etag):
    """Serialize + write back, conditioned on etag. Raises StaleWriteError
    if someone else wrote first (S3 412)."""
    buf = io.StringIO()
    writer = csv.DictWriter(buf, fieldnames=FIELDS)
    writer.writeheader()
    writer.writerows(rows)

    put_kwargs = {"Bucket": BUCKET, "Key": KEY, "Body": buf.getvalue().encode("utf-8")}
    # Conditional write: two Lambdas racing to create or update the same
    # object can never silently clobber one another.
    if etag is None:
        put_kwargs["IfNoneMatch"] = "*"
    else:
        put_kwargs["IfMatch"] = etag

    try:
        _s3.put_object(**put_kwargs)
    except ClientError as exc:
        if exc.response["ResponseMetadata"]["HTTPStatusCode"] == 412:
            raise StaleWriteError(f"{KEY} was modified concurrently") from exc
        raise


@contextmanager
def connect():
    """One open + one close. Raises StaleWriteError on a lost write race —
    callers that need to survive that should use retry(), not catch it
    themselves and retry ad hoc."""
    rows, etag = _open()
    yield rows
    _close(rows, etag)


def retry(mutate, attempts=3, delay_seconds=0.2):
    """Run `mutate(rows) -> result` inside connect(), retrying the whole
    open/mutate/close cycle if a concurrent writer wins the race.

        result = csv_store.retry(lambda rows: rows.append(new_row))

    `mutate` must be safe to call more than once — each retry reruns it
    against a freshly read snapshot of the CSV.
    """
    for attempt in range(1, attempts + 1):
        try:
            with connect() as rows:
                result = mutate(rows)
            return result
        except StaleWriteError:
            if attempt == attempts:
                raise
            time.sleep(delay_seconds * attempt)
