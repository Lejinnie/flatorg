# FlatOrg

A Flutter + Firebase app for scheduling and managing household tasks in a co-living flat.

## Dev Environment Setup

There are two ways to work on this project:

### Option A — Dev Container (recommended)

The devcontainer gives every contributor an identical, pre-configured environment. No manual tool installation needed.

**Prerequisites**

- [Docker](https://docs.docker.com/get-docker/) (Desktop or Engine)
- [VS Code](https://code.visualstudio.com/)
- [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)

**What's inside the container**

| Component | Version / detail |
|---|---|
| OS | Ubuntu 22.04 |
| Python | 3.12 (default `python3`) |
| Node.js | 20 LTS |
| Firebase CLI | latest (`firebase-tools` via npm) |
| Flutter SDK | stable channel, pre-cached for Linux/web (no Android SDK) |
| pre-commit | latest |

VS Code extensions are auto-installed on container start:
- **Dart-Code.flutter** and **Dart-Code.dart-code** — Flutter/Dart language support
- **ms-python.python** and **ms-python.mypy-type-checker** — Python language support
- **charliermarsh.ruff** — linting and formatting for Python

Format-on-save is enabled for both Python (Ruff) and Dart (Dart formatter).

**Steps**

1. Clone the repo and open the folder in VS Code.
2. When prompted *"Reopen in Container"*, click it — or open the command palette and run **Dev Containers: Reopen in Container**.
3. Wait for the image to build. The first build downloads the Flutter SDK and takes a few minutes; subsequent starts are fast.
4. Once the container is ready, `postCreateCommand` runs automatically:
   ```
   pip3 install -r functions_python/requirements.txt \
                -r functions_python/requirements-dev.txt   # Python Cloud Function deps
   flutter pub get                                         # Dart/Flutter deps
   pre-commit install                                      # Git hooks
   ```
   The environment is immediately ready to use — no extra commands needed.

> **Git identity inside the container:** `~/.gitconfig` is bind-mounted from your host, so commits made inside the container carry your correct author name and email automatically.

> **`flutter run` on a physical device:** the container has no Android SDK, so run `flutter run` from a terminal on your **host machine** instead. Your source files are the same on both sides — edits inside the container are immediately visible on the host.

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
