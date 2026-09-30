#!/usr/bin/env python3
import argparse
import json
import logging
import os
import re
import sqlite3
import uuid
from contextlib import contextmanager
from datetime import date
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import unquote, urlsplit


ROOT = Path(__file__).resolve().parent
DEFAULT_DATABASE = Path.home() / "Library" / "Application Support" / "Work Queue" / "work-queue.sqlite3"
LANES = {"action", "external", "internal", "blocked", "done"}
LANE_LABELS = {
    "action": "Perlu gue gerakkan",
    "external": "Nunggu pihak luar",
    "internal": "Nunggu internal",
    "blocked": "Terhambat",
    "done": "Selesai",
}
TASK_FIELDS = ("title", "project", "lane", "owner", "nextAction", "followUpAt")
DATE_PATTERN = re.compile(r"^\d{4}-\d{2}-\d{2}$")
MAX_BODY_SIZE = 64 * 1024
logger = logging.getLogger("work-queue")


class ApiError(Exception):
    def __init__(self, status, message):
        super().__init__(message)
        self.status = status
        self.message = message


def local_date():
    return date.today().isoformat()


def validate_date(value, field, allow_empty=False):
    if allow_empty and value == "":
        return value
    if not isinstance(value, str) or not DATE_PATTERN.fullmatch(value):
        raise ApiError(400, f"{field} harus berupa tanggal YYYY-MM-DD.")
    try:
        date.fromisoformat(value)
    except ValueError as error:
        raise ApiError(400, f"{field} bukan tanggal kalender yang valid.") from error
    return value


def validate_task(payload):
    if not isinstance(payload, dict):
        raise ApiError(400, "Data task harus berupa objek JSON.")

    task = {}
    limits = {"title": 140, "project": 100, "owner": 80, "nextAction": 240}
    for field in ("title", "project", "owner", "nextAction", "lane", "followUpAt"):
        value = payload.get(field)
        if not isinstance(value, str):
            raise ApiError(400, f"Field {field} harus berupa teks.")
        value = " ".join(value.split())
        if field in limits and len(value) > limits[field]:
            raise ApiError(400, f"Field {field} melebihi batas {limits[field]} karakter.")
        task[field] = value

    for field in ("title", "owner", "nextAction"):
        if not task[field]:
            raise ApiError(400, f"Field {field} harus diisi.")
    if task["lane"] not in LANES:
        raise ApiError(400, "Pilih status task yang tersedia.")
    validate_date(task["followUpAt"], "followUpAt", allow_empty=True)
    return task


class WorkQueueHandler(SimpleHTTPRequestHandler):
    database_path = None

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT), **kwargs)

    @contextmanager
    def connect(self):
        connection = sqlite3.connect(self.database_path, timeout=10)
        connection.row_factory = sqlite3.Row
        connection.execute("PRAGMA foreign_keys = ON")
        try:
            yield connection
        finally:
            connection.close()

    def send_json(self, status, payload=None):
        body = b"" if payload is None else json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        if payload is not None:
            self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if body:
            self.wfile.write(body)

    def send_api_error(self, error):
        self.send_json(error.status, {"error": error.message})

    def read_json(self):
        if self.headers.get_content_type() != "application/json":
            raise ApiError(415, "Kirim data dengan Content-Type application/json.")
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError as error:
            raise ApiError(400, "Panjang data request tidak valid.") from error
        if length <= 0:
            raise ApiError(400, "Request tidak berisi data.")
        if length > MAX_BODY_SIZE:
            raise ApiError(413, "Data request terlalu besar.")
        try:
            return json.loads(self.rfile.read(length))
        except (UnicodeDecodeError, json.JSONDecodeError) as error:
            raise ApiError(400, "Request harus berisi JSON yang valid.") from error

    def task_by_id(self, connection, task_id):
        row = connection.execute(
            """
            SELECT id, title, project, lane, owner, next_action, follow_up_at,
                   updated_at, is_example
            FROM tasks
            WHERE id = ?
            """,
            (task_id,),
        ).fetchone()
        if row is None:
            raise ApiError(404, "Task tidak ditemukan.")

        events = connection.execute(
            "SELECT id, date, note FROM events WHERE task_id = ? ORDER BY date, sequence",
            (task_id,),
        ).fetchall()
        return {
            "id": row["id"],
            "title": row["title"],
            "project": row["project"],
            "lane": row["lane"],
            "owner": row["owner"],
            "nextAction": row["next_action"],
            "followUpAt": row["follow_up_at"],
            "updatedAt": row["updated_at"],
            "isExample": bool(row["is_example"]),
            "events": [{"id": event["id"], "date": event["date"], "note": event["note"]} for event in events],
        }

    def add_event(self, connection, task_id, event_date, note, event_id=None):
        connection.execute(
            "INSERT INTO events (id, task_id, date, note) VALUES (?, ?, ?, ?)",
            (event_id or str(uuid.uuid4()), task_id, event_date, note),
        )

    @staticmethod
    def ensure_person(connection, name):
        name = " ".join(name.split())
        connection.execute(
            "INSERT OR IGNORE INTO people (id, name) VALUES (?, ?)",
            (str(uuid.uuid4()), name),
        )
        row = connection.execute(
            "SELECT name FROM people WHERE name = ? COLLATE NOCASE",
            (name,),
        ).fetchone()
        return row["name"]

    def create_task(self, connection, payload):
        task = validate_task(payload)
        task["owner"] = self.ensure_person(connection, task["owner"])
        task_id = payload.get("id")
        if not isinstance(task_id, str) or not task_id.strip() or len(task_id) > 80:
            raise ApiError(400, "Task membutuhkan id yang valid.")
        task_id = task_id.strip()
        is_example = payload.get("isExample") is True
        connection.execute(
            """
            INSERT INTO tasks
                (id, title, project, lane, owner, next_action, follow_up_at, updated_at, is_example)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                task_id, task["title"], task["project"], task["lane"], task["owner"],
                task["nextAction"], task["followUpAt"], local_date(), int(is_example),
            ),
        )
        events = payload.get("events")
        if isinstance(events, list):
            if len(events) > 100:
                raise ApiError(400, "Task memiliki terlalu banyak catatan.")
            for event in events:
                if not isinstance(event, dict):
                    raise ApiError(400, "Setiap catatan update harus berupa objek.")
                event_date = validate_date(event.get("date"), "Tanggal update")
                note = event.get("note")
                if not isinstance(note, str) or not note.strip() or len(note) > 240:
                    raise ApiError(400, "Setiap catatan update harus berisi maksimal 240 karakter.")
                self.add_event(connection, task_id, event_date, note.strip())
        else:
            self.add_event(connection, task_id, local_date(), "Task dibuat.")
        return self.task_by_id(connection, task_id)

    def api_tasks(self, method, path):
        if path == "/api/people":
            if method == "GET":
                with self.connect() as connection:
                    rows = connection.execute("SELECT id, name FROM people ORDER BY name COLLATE NOCASE, id").fetchall()
                self.send_json(200, {"people": [{"id": row["id"], "name": row["name"]} for row in rows]})
                return

            if method == "POST":
                payload = self.read_json()
                name = payload.get("name") if isinstance(payload, dict) else None
                if not isinstance(name, str):
                    raise ApiError(400, "Nama orang harus berupa teks.")
                name = " ".join(name.split())
                if not name:
                    raise ApiError(400, "Nama orang harus diisi.")
                if len(name) > 80:
                    raise ApiError(400, "Nama orang tidak boleh lebih dari 80 karakter.")
                with self.connect() as connection, connection:
                    duplicate = connection.execute(
                        "SELECT id FROM people WHERE name = ? COLLATE NOCASE",
                        (name,),
                    ).fetchone()
                    if duplicate is not None:
                        raise ApiError(409, "Nama orang ini sudah ada.")
                    connection.execute(
                        "INSERT INTO people (id, name) VALUES (?, ?)",
                        (str(uuid.uuid4()), name),
                    )
                    row = connection.execute(
                        "SELECT id, name FROM people WHERE name = ? COLLATE NOCASE",
                        (name,),
                    ).fetchone()
                self.send_json(201, {"person": {"id": row["id"], "name": row["name"]}})
                return

            raise ApiError(405, "Metode ini tidak tersedia untuk daftar orang.")

        if path == "/api/tasks/import" and method == "POST":
            payload = self.read_json()
            imported = payload.get("tasks") if isinstance(payload, dict) else None
            if not isinstance(imported, list) or len(imported) > 250:
                raise ApiError(400, "Impor harus berisi maksimal 250 task.")
            with self.connect() as connection, connection:
                existing = connection.execute("SELECT COUNT(*) FROM tasks").fetchone()[0]
                if existing:
                    raise ApiError(409, "Database sudah berisi task. Impor browser dibatalkan.")
                result = [self.create_task(connection, task) for task in imported]
            self.send_json(201, {"tasks": result})
            return

        if path == "/api/tasks":
            if method == "GET":
                with self.connect() as connection:
                    rows = connection.execute("SELECT id FROM tasks ORDER BY updated_at DESC, id").fetchall()
                    result = [self.task_by_id(connection, row["id"]) for row in rows]
                self.send_json(200, {"tasks": result})
                return

            if method == "POST":
                payload = self.read_json()
                with self.connect() as connection, connection:
                    result = self.create_task(connection, payload)
                self.send_json(201, {"task": result})
                return

            raise ApiError(405, "Metode ini tidak tersedia untuk daftar task.")

        parts = path.split("/")
        if len(parts) == 4 and parts[:2] == ["", "api"] and parts[2] == "tasks" and parts[3]:
            task_id = unquote(parts[3])
            if method == "PUT":
                payload = self.read_json()
                task = validate_task(payload)
                with self.connect() as connection, connection:
                    current = connection.execute(
                        """
                        SELECT lane, owner, title, project, next_action, follow_up_at
                        FROM tasks
                        WHERE id = ?
                        """,
                        (task_id,),
                    ).fetchone()
                    if current is None:
                        raise ApiError(404, "Task tidak ditemukan.")
                    task["owner"] = self.ensure_person(connection, task["owner"])
                    connection.execute(
                        """
                        UPDATE tasks
                        SET title = ?, project = ?, lane = ?, owner = ?, next_action = ?,
                            follow_up_at = ?, updated_at = ?, is_example = 0
                        WHERE id = ?
                        """,
                        (
                            task["title"], task["project"], task["lane"], task["owner"],
                            task["nextAction"], task["followUpAt"], local_date(), task_id,
                        ),
                    )
                    today = local_date()
                    if current["lane"] != task["lane"]:
                        self.add_event(connection, task_id, today, f"Status diubah ke {LANE_LABELS[task['lane']]}.")
                    if current["owner"] != task["owner"]:
                        self.add_event(connection, task_id, today, f"Penanggung jawab diubah ke {task['owner']}.")
                    if current["title"] != task["title"]:
                        self.add_event(connection, task_id, today, "Nama task diperbarui.")
                    if current["project"] != task["project"]:
                        self.add_event(connection, task_id, today, "Proyek task diperbarui.")
                    if current["next_action"] != task["nextAction"]:
                        self.add_event(connection, task_id, today, "Langkah berikutnya diperbarui.")
                    if current["follow_up_at"] != task["followUpAt"]:
                        note = (
                            f"Jadwal follow-up diatur ke {task['followUpAt']}."
                            if task["followUpAt"]
                            else "Jadwal follow-up dihapus."
                        )
                        self.add_event(connection, task_id, today, note)
                    result = self.task_by_id(connection, task_id)
                self.send_json(200, {"task": result})
                return

            if method == "DELETE":
                with self.connect() as connection, connection:
                    cursor = connection.execute("DELETE FROM tasks WHERE id = ?", (task_id,))
                    if cursor.rowcount == 0:
                        raise ApiError(404, "Task tidak ditemukan.")
                self.send_json(204)
                return

        if (
            len(parts) == 5
            and parts[:2] == ["", "api"]
            and parts[2] == "tasks"
            and parts[3]
            and parts[4] == "events"
            and method == "POST"
        ):
            task_id = unquote(parts[3])
            payload = self.read_json()
            event_date = validate_date(payload.get("date") if isinstance(payload, dict) else None, "Tanggal update")
            note = payload.get("note") if isinstance(payload, dict) else None
            if not isinstance(note, str) or not note.strip() or len(note) > 240:
                raise ApiError(400, "Catatan update harus berisi maksimal 240 karakter.")
            with self.connect() as connection, connection:
                cursor = connection.execute(
                    "UPDATE tasks SET updated_at = ?, is_example = 0 WHERE id = ?",
                    (local_date(), task_id),
                )
                if cursor.rowcount == 0:
                    raise ApiError(404, "Task tidak ditemukan.")
                self.add_event(connection, task_id, event_date, note.strip())
                result = self.task_by_id(connection, task_id)
            self.send_json(201, {"task": result})
            return

        raise ApiError(404, "Alamat API tidak ditemukan.")

    def handle_api(self, method):
        path = urlsplit(self.path).path
        try:
            self.api_tasks(method, path)
        except ApiError as error:
            self.send_api_error(error)
        except sqlite3.IntegrityError:
            self.send_json(409, {"error": "Data bertabrakan dengan task yang sudah tersimpan."})
        except sqlite3.Error:
            logger.exception("SQLite request failed.")
            self.send_json(
                500,
                {"error": "SQLite gagal membaca atau menyimpan data. Periksa lokasi dan izin database."},
            )

    def do_GET(self):
        if urlsplit(self.path).path.startswith("/api/"):
            self.handle_api("GET")
        else:
            super().do_GET()

    def do_POST(self):
        self.handle_api("POST")

    def do_PUT(self):
        self.handle_api("PUT")

    def do_DELETE(self):
        self.handle_api("DELETE")

    def log_message(self, format_string, *args):
        logger.info("%s - %s", self.address_string(), format_string % args)


def initialize_database(database_path):
    database_path.parent.mkdir(parents=True, exist_ok=True)
    connection = sqlite3.connect(database_path, timeout=10)
    connection.row_factory = sqlite3.Row
    try:
        connection.execute("PRAGMA journal_mode = WAL")
        version = connection.execute("PRAGMA user_version").fetchone()[0]
        if version > 2:
            raise RuntimeError(f"Versi database {version} lebih baru dari versi aplikasi ini.")
        if version == 0:
            with connection:
                connection.execute(
                    """
                    CREATE TABLE tasks (
                        id TEXT PRIMARY KEY,
                        title TEXT NOT NULL,
                        project TEXT NOT NULL DEFAULT '',
                        lane TEXT NOT NULL CHECK (lane IN ('action', 'external', 'internal', 'blocked', 'done')),
                        owner TEXT NOT NULL,
                        next_action TEXT NOT NULL,
                        follow_up_at TEXT NOT NULL DEFAULT '',
                        updated_at TEXT NOT NULL,
                        is_example INTEGER NOT NULL DEFAULT 0 CHECK (is_example IN (0, 1))
                    )
                    """
                )
                connection.execute(
                    """
                    CREATE TABLE events (
                        sequence INTEGER PRIMARY KEY AUTOINCREMENT,
                        id TEXT NOT NULL UNIQUE,
                        task_id TEXT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
                        date TEXT NOT NULL,
                        note TEXT NOT NULL
                    )
                    """
                )
                connection.execute("CREATE INDEX tasks_updated_at_idx ON tasks(updated_at)")
                connection.execute("CREATE INDEX events_task_date_idx ON events(task_id, date, sequence)")
                connection.execute("PRAGMA user_version = 1")
            version = 1
        if version == 1:
            with connection:
                connection.execute(
                    """
                    CREATE TABLE people (
                        id TEXT PRIMARY KEY,
                        name TEXT NOT NULL COLLATE NOCASE UNIQUE
                    )
                    """
                )
                owners = {}
                for row in connection.execute(
                    "SELECT id, owner FROM tasks ORDER BY id"
                ).fetchall():
                    name = " ".join(row["owner"].split())
                    if name:
                        owners.setdefault(name.casefold(), name)
                owners["gue"] = "Gue"
                for name in sorted(owners.values(), key=str.casefold):
                    connection.execute(
                        "INSERT OR IGNORE INTO people (id, name) VALUES (?, ?)",
                        (str(uuid.uuid4()), name),
                    )
                for row in connection.execute("SELECT id, owner FROM tasks").fetchall():
                    name = " ".join(row["owner"].split())
                    if name:
                        person = connection.execute(
                            "SELECT name FROM people WHERE name = ? COLLATE NOCASE",
                            (name,),
                        ).fetchone()
                        connection.execute(
                            "UPDATE tasks SET owner = ? WHERE id = ?",
                            (person["name"], row["id"]),
                        )
                connection.execute("PRAGMA user_version = 2")
    finally:
        connection.close()


def main():
    parser = argparse.ArgumentParser(description="Jalankan Work queue dengan database SQLite lokal.")
    parser.add_argument("--port", type=int, default=4173)
    parser.add_argument(
        "--db",
        type=Path,
        default=Path(os.environ.get("WORK_QUEUE_DB", DEFAULT_DATABASE)),
        help="Lokasi file SQLite. Bisa juga diatur lewat WORK_QUEUE_DB.",
    )
    args = parser.parse_args()
    database_path = args.db.expanduser().resolve()
    initialize_database(database_path)
    WorkQueueHandler.database_path = database_path

    server = ThreadingHTTPServer(("127.0.0.1", args.port), WorkQueueHandler)
    logger.info("Work queue: http://127.0.0.1:%s", server.server_port)
    logger.info("SQLite database: %s", database_path)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        logger.info("Stopping Work queue.")
    finally:
        server.server_close()


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    main()
