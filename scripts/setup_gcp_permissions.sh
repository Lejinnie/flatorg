#!/usr/bin/env bash
# Sets up GCP project permissions and Artifact Registry policies needed for
# Firebase Cloud Functions (Gen 2 / Python) to build and run correctly.
#
# Run this once after project creation or after a permission regression.
# Requires: gcloud CLI authenticated with an account that has Owner/Editor rights
#           on the flatorg-61826 project.
#
# Usage:
#   bash scripts/setup_gcp_permissions.sh

set -euo pipefail

PROJECT_ID="flatorg-61826"
PROJECT_NUMBER="854474953690"
REGION="us-central1"
BUILD_SA="${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
info()    { echo "[INFO]  $*"; }
success() { echo "[OK]    $*"; }
skip()    { echo "[SKIP]  $*"; }

has_role() {
    local member="$1"
    local role="$2"
    gcloud projects get-iam-policy "${PROJECT_ID}" \
        --flatten="bindings[].members" \
        --filter="bindings.members:${member} AND bindings.role:${role}" \
        --format="value(bindings.role)" 2>/dev/null | grep -q "${role}"
}

grant_role_if_missing() {
    local member="$1"
    local role="$2"
    if has_role "${member}" "${role}"; then
        skip "${role} already granted to ${member}"
    else
        info "Granting ${role} to ${member} ..."
        gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
            --member="serviceAccount:${member}" \
            --role="${role}" \
            --quiet
        success "${role} granted."
    fi
}

# ---------------------------------------------------------------------------
# Issue 2 — Cloud Build service account permissions
# Only applies the fix if any required role is missing; does nothing if the
# last deploy already succeeded and all roles are in place.
# ---------------------------------------------------------------------------
info "Checking Cloud Build service account permissions (Issue #2) ..."
ROLES_NEEDED=(
    "roles/artifactregistry.writer"   # push container images to Artifact Registry
    "roles/logging.logWriter"         # write build logs to Cloud Logging
    "roles/storage.objectAdmin"       # read/write build artifact buckets
    "roles/iam.serviceAccountUser"    # act as the Cloud Functions runtime SA
)
for role in "${ROLES_NEEDED[@]}"; do
    grant_role_if_missing "${BUILD_SA}" "${role}"
done

# ---------------------------------------------------------------------------
# Issue 1 — Artifact Registry image retention
# The gcf-artifacts repository (created automatically by Cloud Functions)
# may have an aggressive cleanup policy (as short as 1 day) that deletes
# function container images shortly after deploy, making functions fail at
# invocation time.  We set a keep-most-recent-10 policy so images persist.
# ---------------------------------------------------------------------------
info "Configuring Artifact Registry cleanup policy for gcf-artifacts (Issue #1) ..."

REPO="gcf-artifacts"

# Ensure the repository exists before touching its policy.
if ! gcloud artifacts repositories describe "${REPO}" \
        --location="${REGION}" \
        --project="${PROJECT_ID}" &>/dev/null; then
    info "Repository ${REPO} does not exist yet — it will be created on first deploy."
    info "Re-run this script after the first successful 'firebase deploy --only functions'."
    exit 0
fi

# Write the cleanup policy as a JSON file and apply it.
POLICY_FILE="$(mktemp /tmp/gcf-cleanup-policy.XXXXXX.json)"
cat > "${POLICY_FILE}" <<'EOF'
[
  {
    "name": "keep-most-recent-10",
    "action": {"type": "Keep"},
    "mostRecentVersions": {
      "keepCount": 10
    }
  },
  {
    "name": "delete-old-versions",
    "action": {"type": "Delete"},
    "olderThan": "30d"
  }
]
EOF

gcloud artifacts repositories set-cleanup-policies "${REPO}" \
    --location="${REGION}" \
    --project="${PROJECT_ID}" \
    --policy="${POLICY_FILE}" \
    --quiet

rm -f "${POLICY_FILE}"

success "Cleanup policy applied: keep 10 most recent versions, delete after 30 days."
info "Done. Re-run 'firebase deploy --only functions' to verify a clean build."
