# FlatOrg

A Flutter + Firebase app for scheduling and managing household tasks in a co-living flat.

## Dev Environment Setup

There are two ways to work on this project:

### Option A — Dev Container (recommended)

Uses Docker to give everyone an identical environment with Python 3.12, Firebase CLI, Flutter, and all linters pre-installed. No manual tool installation needed.

**Prerequisites:** [Docker](https://docs.docker.com/get-docker/) + [VS Code](https://code.visualstudio.com/) + the [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers).

1. Clone the repo and open it in VS Code.
2. When prompted "Reopen in Container", click it (or run **Dev Containers: Reopen in Container** from the command palette).
3. Wait for the image to build — on first run this takes a few minutes (Flutter SDK download).
4. Done. `postCreateCommand` automatically runs `pip install`, `flutter pub get`, and `pre-commit install`.

> **`flutter run` on a physical device:** run this from a terminal on your **host machine** (outside the container), not inside it. The project folder is the same files — edits made inside the container are immediately visible on the host.

---

### Option B — Manual setup

Install the following tools on your machine:

| Tool | Version |
|---|---|
| Flutter | stable channel (`>=3.10.0`) |
| Python | 3.12 |
| Node.js | 20 LTS |
| Firebase CLI | latest (`npm install -g firebase-tools`) |
| pre-commit | latest (`pip install pre-commit`) |

Then run:

```bash
# Flutter dependencies
flutter pub get

# Python dependencies (Cloud Functions)
pip install -r functions_python/requirements.txt -r functions_python/requirements-dev.txt

# Git hooks (ruff, mypy, flutter analyze run on every commit)
pre-commit install
```

---

## Project Structure

```
.
├── lib/                        # Flutter app source
├── functions_python/           # Firebase Cloud Functions (Python 3.12)
│   ├── main.py                 # Function entry points
│   ├── triggers/               # Cloud Function handlers
│   ├── services/               # Business logic
│   ├── models/                 # Data models
│   ├── repository/             # Firestore data access
│   └── tests/                  # pytest test suite
├── .devcontainer/              # Dev Container config (Docker)
├── .github/workflows/          # CI: ruff, mypy, flutter analyze
├── scripts/
│   └── setup_gcp_permissions.sh  # One-time GCP IAM + Artifact Registry setup
└── firestore.rules             # Firestore security rules
```

## GCP Setup (first time only)

After creating the Firebase project, run this once to grant the Cloud Build service account the correct permissions and set a sensible Artifact Registry image retention policy:

```bash
bash scripts/setup_gcp_permissions.sh
```

## Running Tests

```bash
# Python (Cloud Functions)
cd functions_python
pytest

# Flutter
flutter test
```

## Code Quality

Pre-commit hooks run automatically on `git commit`. To run them manually:

```bash
pre-commit run --all-files
```

The CI pipeline (`.github/workflows/ci.yml`) runs the same checks on every push and pull request.
