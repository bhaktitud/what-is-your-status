# What's Your Status?

Personal work command center for tracking who has the next move, what action comes next, and when to follow up.

## Run it (Native macOS App)

Build and package the standalone SwiftUI macOS application bundle:

```bash
./scripts/build-app.sh
open "build/What's Your Status.app"
```

You can also run directly during development with `swift run WhatsYourStatus` and run the Swift SQLite test suite with `swift test`.

## Run it (Web Server)

Run `python3 server.py` in this folder, then open `http://localhost:4173`. Python's standard library handles both the web server and SQLite. The app has no build step or third-party dependencies. Stop the server with Ctrl+C.

Tasks, their update history, and the saved people list are stored in a SQLite database at `~/Library/Application Support/Work Queue/work-queue.sqlite3` on macOS. Both the native macOS app and the local web server read and write the same SQLite database file. The database remains after the app or browser closes. People you add are available in the “Giliran ada pada” selector. Existing task owners are added to the people list when the database is upgraded. To choose another database file, set `WORK_QUEUE_DB=/path/to/work-queue.sqlite3` (or pass `--db` to `server.py`).

The server listens on this computer only at `127.0.0.1`. Data does not sync to other devices. If the browser already has tasks from the earlier prototype, the app copies them to an empty database once and removes the old browser copy only after the import succeeds. Use “Coba contoh dari skenario kamu” on the empty screen to save the example task from the brief.

Run the SQLite API tests with `python3 -m unittest -v test_server.py`.

## Design decisions

- Light surfaces and dark navy text follow the requested white, cool-gray work environment and keep dense task details readable.
- Electric blue marks the primary action and current filter so the most important controls are easy to find.
- Semantic status colors distinguish action required, external waiting, internal waiting, blocked, and done without using color as the only label.
- Geist is preferred for a crisp product interface, with Inter and system fonts as local fallbacks.
- The queue groups work by who needs to move next. Task details keep the update history beside the next action instead of making a timeline the home screen.
- Motion stays limited to hover states; dialogs open without decorative animation.
# whats-your-status
