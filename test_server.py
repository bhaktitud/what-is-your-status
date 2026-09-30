import json
import sqlite3
import tempfile
import threading
import unittest
from http.server import ThreadingHTTPServer
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import Request, urlopen

from server import WorkQueueHandler, initialize_database


class WorkQueueApiTests(unittest.TestCase):
    def setUp(self):
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.database_path = Path(self.temporary_directory.name) / "work-queue.sqlite3"
        initialize_database(self.database_path)
        self.start_server()

    def tearDown(self):
        self.stop_server()
        self.temporary_directory.cleanup()

    def start_server(self):
        handler = type(
            "TestWorkQueueHandler",
            (WorkQueueHandler,),
            {"database_path": self.database_path},
        )
        self.server = ThreadingHTTPServer(("127.0.0.1", 0), handler)
        self.server.daemon_threads = True
        self.server_thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.server_thread.start()
        self.base_url = f"http://127.0.0.1:{self.server.server_port}"

    def stop_server(self):
        self.server.shutdown()
        self.server.server_close()
        self.server_thread.join(timeout=3)

    def request(self, method, path, payload=None):
        body = None if payload is None else json.dumps(payload).encode("utf-8")
        request = Request(
            f"{self.base_url}{path}",
            data=body,
            method=method,
            headers={"Content-Type": "application/json"} if body is not None else {},
        )
        try:
            response = urlopen(request, timeout=3)
        except HTTPError as error:
            response = error
        with response:
            raw = response.read()
            return response.status, json.loads(raw) if raw else None

    @staticmethod
    def task_payload(**overrides):
        task = {
            "id": "task-1",
            "title": "Integrasi WebBeds ke TourPlan",
            "project": "Integrasi",
            "lane": "action",
            "owner": "Gue",
            "nextAction": "Follow up mapping process",
            "followUpAt": "",
            "isExample": False,
        }
        task.update(overrides)
        return task

    def create_task(self, **overrides):
        return self.request("POST", "/api/tasks", self.task_payload(**overrides))

    def test_task_and_timeline_persist_and_survive_server_restart(self):
        task = self.task_payload(
            isExample=True,
            events=[
                {"date": "2026-10-12", "note": "Email ke Jared sudah dikirim"},
                {"date": "2026-10-13", "note": "Jared sudah membalas"},
            ],
        )
        status, created = self.request("POST", "/api/tasks", task)
        self.assertEqual(status, 201)
        self.assertEqual([event["date"] for event in created["task"]["events"]], ["2026-10-12", "2026-10-13"])

        self.stop_server()
        initialize_database(self.database_path)
        self.start_server()

        status, result = self.request("GET", "/api/tasks")
        self.assertEqual(status, 200)
        self.assertEqual(len(result["tasks"]), 1)
        self.assertEqual(result["tasks"][0]["title"], task["title"])
        self.assertEqual(result["tasks"][0]["events"][1]["note"], "Jared sudah membalas")

    def test_editing_owner_and_status_records_history(self):
        self.create_task()
        status, result = self.request(
            "PUT",
            "/api/tasks/task-1",
            self.task_payload(lane="external", owner="Jared", followUpAt="2026-10-20"),
        )
        self.assertEqual(status, 200)
        self.assertEqual(result["task"]["lane"], "external")
        self.assertEqual(result["task"]["owner"], "Jared")
        self.assertEqual(result["task"]["followUpAt"], "2026-10-20")
        changes = [event["note"] for event in result["task"]["events"]]
        self.assertIn("Status diubah ke Nunggu pihak luar.", changes)
        self.assertIn("Penanggung jawab diubah ke Jared.", changes)
        self.assertIn("Jadwal follow-up diatur ke 2026-10-20.", changes)

    def test_editing_next_action_is_recorded_in_the_timeline(self):
        self.create_task()
        status, result = self.request(
            "PUT",
            "/api/tasks/task-1",
            self.task_payload(nextAction="Tunggu balasan dari Jared"),
        )
        self.assertEqual(status, 200)
        self.assertEqual(result["task"]["nextAction"], "Tunggu balasan dari Jared")
        self.assertIn(
            "Langkah berikutnya diperbarui.",
            [event["note"] for event in result["task"]["events"]],
        )

    def test_people_can_be_added_and_existing_names_are_normalized(self):
        status, result = self.request("POST", "/api/people", {"name": "  Jared   Smith  "})
        self.assertEqual(status, 201)
        self.assertEqual(result["person"]["name"], "Jared Smith")

        status, result = self.request("POST", "/api/people", {"name": "jared smith"})
        self.assertEqual(status, 409)

        status, result = self.request("GET", "/api/people")
        self.assertEqual(status, 200)
        self.assertEqual([person["name"] for person in result["people"]], ["Gue", "Jared Smith"])

        self.stop_server()
        self.start_server()
        self.assertEqual(
            [person["name"] for person in self.request("GET", "/api/people")[1]["people"]],
            ["Gue", "Jared Smith"],
        )

    def test_task_owners_are_added_to_the_people_list(self):
        status, result = self.create_task(owner="  Someone   New  ")
        self.assertEqual(status, 201)
        self.assertEqual(result["task"]["owner"], "Someone New")
        people = self.request("GET", "/api/people")[1]["people"]
        self.assertIn("Someone New", [person["name"] for person in people])

    def test_version_one_database_migrates_existing_owners_without_losing_history(self):
        legacy_path = Path(self.temporary_directory.name) / "version-one.sqlite3"
        with sqlite3.connect(legacy_path) as connection:
            connection.executescript(
                """
                CREATE TABLE tasks (
                    id TEXT PRIMARY KEY, title TEXT NOT NULL, project TEXT NOT NULL DEFAULT '',
                    lane TEXT NOT NULL, owner TEXT NOT NULL, next_action TEXT NOT NULL,
                    follow_up_at TEXT NOT NULL DEFAULT '', updated_at TEXT NOT NULL, is_example INTEGER NOT NULL DEFAULT 0
                );
                CREATE TABLE events (
                    sequence INTEGER PRIMARY KEY AUTOINCREMENT, id TEXT NOT NULL UNIQUE,
                    task_id TEXT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE, date TEXT NOT NULL, note TEXT NOT NULL
                );
                INSERT INTO tasks VALUES ('legacy-task', 'Task lama', '', 'external', '  Jared   Smith  ', 'Tunggu balasan', '', '2026-09-30', 0);
                INSERT INTO events (id, task_id, date, note) VALUES ('legacy-event', 'legacy-task', '2026-09-30', 'Sudah email');
                PRAGMA user_version = 1;
                """
            )

        initialize_database(legacy_path)
        with sqlite3.connect(legacy_path) as connection:
            self.assertEqual(connection.execute("PRAGMA user_version").fetchone()[0], 2)
            self.assertEqual(connection.execute("SELECT name FROM people ORDER BY name COLLATE NOCASE").fetchall(), [("Gue",), ("Jared Smith",)])
            self.assertEqual(connection.execute("SELECT owner FROM tasks WHERE id = 'legacy-task'").fetchone(), ("Jared Smith",))
            self.assertEqual(connection.execute("SELECT note FROM events WHERE id = 'legacy-event'").fetchone(), ("Sudah email",))

    def test_adding_update_and_completing_task_are_persisted(self):
        self.create_task()
        status, update = self.request(
            "POST",
            "/api/tasks/task-1/events",
            {"date": "2026-10-14", "note": "Jared meminta rincian mapping."},
        )
        self.assertEqual(status, 201)
        self.assertEqual(update["task"]["events"][-1]["note"], "Jared meminta rincian mapping.")

        completed = self.task_payload(lane="done")
        status, result = self.request("PUT", "/api/tasks/task-1", completed)
        self.assertEqual(status, 200)
        self.assertEqual(result["task"]["lane"], "done")
        self.assertIn("Status diubah ke Selesai.", [event["note"] for event in result["task"]["events"]])

    def test_legacy_import_is_atomic_and_only_runs_on_an_empty_database(self):
        valid = self.task_payload(events=[{"date": "2026-10-13", "note": "Jared sudah membalas"}])
        invalid = self.task_payload(id="task-2", followUpAt="bukan-tanggal")
        status, result = self.request("POST", "/api/tasks/import", {"tasks": [valid, invalid]})
        self.assertEqual(status, 400)
        self.assertIn("tanggal", result["error"])
        self.assertEqual(self.request("GET", "/api/tasks")[1]["tasks"], [])

        status, result = self.request("POST", "/api/tasks/import", {"tasks": [valid]})
        self.assertEqual(status, 201)
        self.assertEqual(result["tasks"][0]["events"][0]["note"], "Jared sudah membalas")

        status, result = self.request("POST", "/api/tasks/import", {"tasks": [valid]})
        self.assertEqual(status, 409)
        self.assertEqual(len(self.request("GET", "/api/tasks")[1]["tasks"]), 1)

    def test_invalid_data_is_rejected_without_saving(self):
        status, result = self.create_task(followUpAt="2026-02-30")
        self.assertEqual(status, 400)
        self.assertIn("tanggal", result["error"])

        status, result = self.create_task(nextAction="")
        self.assertEqual(status, 400)
        self.assertEqual(result["error"], "Field nextAction harus diisi.")

        status, result = self.request("GET", "/api/tasks")
        self.assertEqual(status, 200)
        self.assertEqual(result["tasks"], [])

    def test_text_is_returned_as_data_and_not_executed_as_html(self):
        title = "<img src=x onerror=alert(1)>"
        status, created = self.create_task(title=title)
        self.assertEqual(status, 201)
        self.assertEqual(created["task"]["title"], title)
        self.assertEqual(self.request("GET", "/api/tasks")[1]["tasks"][0]["title"], title)

    def test_delete_removes_task_and_its_timeline(self):
        self.create_task()
        self.request("POST", "/api/tasks/task-1/events", {"date": "2026-10-14", "note": "Update"})
        status, result = self.request("DELETE", "/api/tasks/task-1")
        self.assertEqual(status, 204)
        self.assertIsNone(result)
        self.assertEqual(self.request("GET", "/api/tasks")[1]["tasks"], [])
        self.assertEqual(self.request("DELETE", "/api/tasks/task-1")[0], 404)

    def test_database_initialization_rejects_unknown_future_version(self):
        unsupported = Path(self.temporary_directory.name) / "future.sqlite3"
        with sqlite3.connect(unsupported) as connection:
            connection.execute("PRAGMA user_version = 3")
        with self.assertRaisesRegex(RuntimeError, "lebih baru"):
            initialize_database(unsupported)


if __name__ == "__main__":
    unittest.main()
