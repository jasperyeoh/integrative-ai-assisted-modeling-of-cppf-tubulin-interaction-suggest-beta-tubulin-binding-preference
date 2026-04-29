#!/usr/bin/env bash
# Upload large MD trajectories to Zenodo from this server (bucket API).
# Token: export ZENODO_TOKEN='...'  OR  single line in ~/.zenodo_token (chmod 600).
# Never commit tokens. Revoke any token that was pasted in chat/email.
#
# Usage:
#   bash revision_exec/scripts/zenodo_upload_trajectories.sh --dry-run
#   bash revision_exec/scripts/zenodo_upload_trajectories.sh              # create draft + upload files
#   bash revision_exec/scripts/zenodo_upload_trajectories.sh --publish     # upload + publish (gets DOI)
#
# Long runs: use tmux/screen; each file is one full PUT (resume = re-run same command after fixing network).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ZENODO_API="${ZENODO_API:-https://zenodo.org/api}"
TOKEN_FILE="${ZENODO_TOKEN_FILE:-$HOME/.zenodo_token}"
DRY_RUN=0
DO_PUBLISH=0

load_token() {
  if [[ -n "${ZENODO_TOKEN:-}" ]]; then
    return 0
  fi
  if [[ -f "$TOKEN_FILE" ]]; then
    ZENODO_TOKEN="$(head -1 "$TOKEN_FILE" | tr -d '\r\n')"
    export ZENODO_TOKEN
    return 0
  fi
  return 1
}

# Zenodo object key must be unique — never use bare basename (many reps share md_200ns.xtc).
zenodo_remote_name() {
  local f="$1"
  if [[ "$f" =~ /(monomer_[^/]+)/prod/([^/]+)$ ]]; then
    echo "${BASH_REMATCH[1]}_${BASH_REMATCH[2]}"
    return
  fi
  if [[ "$f" =~ /rep([0-9]+)/prod/([^/]+)$ ]]; then
    echo "dimer_rep${BASH_REMATCH[1]}_${BASH_REMATCH[2]}"
    return
  fi
  basename "$f"
}

# Default: production trajectories + rep1 extension chunk (same as LARGE_FILES_NOT_IN_GIT core set).
DEFAULT_RELS=(
  revision_exec/monomer_alpha_rep1/prod/md_200ns.xtc
  revision_exec/monomer_alpha_rep2/prod/md_200ns.xtc
  revision_exec/monomer_beta_rep1/prod/md_200ns.xtc
  revision_exec/rep1/prod/md_200ns.xtc
  revision_exec/rep2/prod/md_200ns.xtc
  revision_exec/rep3/prod/md_200ns.xtc
  revision_exec/rep1/prod/md_350ns.part0004.xtc
)

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --publish) DO_PUBLISH=1; shift ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

FILES=()
for rel in "${DEFAULT_RELS[@]}"; do
  FILES+=("$ROOT/$rel")
done

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "=== Zenodo upload dry-run (repo: $ROOT) ==="
  total=0
  for f in "${FILES[@]}"; do
    if [[ ! -f "$f" ]]; then
      echo "MISSING: $f" >&2
      exit 1
    fi
    sz=$(stat -c%s "$f")
    total=$((total + sz))
    key="$(zenodo_remote_name "$f")"
    echo "  $key  <=  $(basename "$f")  ($sz bytes)"
  done
  echo "Total ~ $(( total / 1024 / 1024 / 1024 )) GiB (approx)"
  echo "Token: $([[ -n "${ZENODO_TOKEN:-}" ]] && echo set || ([[ -f "$TOKEN_FILE" ]] && echo "file $TOKEN_FILE" || echo NOT SET))"
  exit 0
fi

if ! load_token; then
  echo "ERROR: Set ZENODO_TOKEN or create $TOKEN_FILE (one line, chmod 600)." >&2
  exit 1
fi

echo "Creating new deposition (draft)..."
CREATE_JSON="$(curl -sS -X POST "${ZENODO_API}/deposit/depositions" \
  -H "Authorization: Bearer ${ZENODO_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{}')"

DEP_ID="$(python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('id','')); sys.exit(0 if d.get('id') else 1)" <<<"$CREATE_JSON")" || {
  echo "Zenodo create failed:" >&2
  echo "$CREATE_JSON" >&2
  exit 1
}
BUCKET="$(python3 -c "import json,sys; print(json.load(sys.stdin)['links']['bucket'])" <<<"$CREATE_JSON")"
echo "Deposition id: $DEP_ID"
echo "Bucket: $BUCKET"

META_JSON="$(python3 <<'PY'
import json, textwrap
meta = {
  "metadata": {
    "title": "MD trajectories (xtc) – CPPF–tubulin heterodimer and monomers",
    "upload_type": "dataset",
    "description": "<p>All-atom GROMACS trajectories for tubulin–CPPF revision MD: three dimer replicates (200 ns), monomer alpha/beta replicates (200 ns where completed), and dimer rep1 extension segment (md_350ns.part0004.xtc). Matching tpr/topology and workflow are in the GitHub repository linked from the project.</p>",
    "creators": [{"name": "Yang, J.", "affiliation": "See publication"}],
    "access_right": "open",
    "license": "cc-by-4.0",
  }
}
print(json.dumps(meta))
PY
)"

echo "Updating metadata..."
curl -sS -o /tmp/zenodo_meta_resp.json -w "%{http_code}" -X PUT "${ZENODO_API}/deposit/depositions/${DEP_ID}" \
  -H "Authorization: Bearer ${ZENODO_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "$META_JSON" | tee /tmp/zenodo_meta_code.txt >/dev/null
HTTP="$(cat /tmp/zenodo_meta_code.txt)"
if [[ "$HTTP" != "200" ]]; then
  echo "Metadata PUT failed HTTP=$HTTP" >&2
  cat /tmp/zenodo_meta_resp.json >&2 || true
  exit 1
fi

SUMS="$ROOT/revision_exec/ZENODO_UPLOAD_SHA256SUMS.txt"
: >"$SUMS"
for f in "${FILES[@]}"; do
  key="$(zenodo_remote_name "$f")"
  echo "sha256sum $key ..."
  sha256sum "$f" | awk -v k="$key" '{print $1"  "k}' >>"$SUMS"
done

echo "Uploading checksum manifest..."
curl -fS --upload-file "$SUMS" \
  -H "Authorization: Bearer ${ZENODO_TOKEN}" \
  "${BUCKET}/ZENODO_UPLOAD_SHA256SUMS.txt"

for f in "${FILES[@]}"; do
  key="$(zenodo_remote_name "$f")"
  echo "=== Uploading $key <= $f ($(du -h "$f" | cut -f1)) ==="
  curl -fS --upload-file "$f" \
    -H "Authorization: Bearer ${ZENODO_TOKEN}" \
    "${BUCKET}/${key}"
done

if [[ "$DO_PUBLISH" -eq 1 ]]; then
  echo "Publishing..."
  PUB="$(curl -sS -X POST "${ZENODO_API}/deposit/depositions/${DEP_ID}/actions/publish" \
    -H "Authorization: Bearer ${ZENODO_TOKEN}")"
  echo "$PUB" | python3 -c "import json,sys; d=json.load(sys.stdin); print('doi:', d.get('doi')); print('doi_url:', d.get('doi_url'))" 2>/dev/null || echo "$PUB"
else
  echo "Draft only. Review at: https://zenodo.org/deposit/${DEP_ID}"
  echo "To publish later: curl -X POST .../depositions/${DEP_ID}/actions/publish -H \"Authorization: Bearer \$ZENODO_TOKEN\""
  echo "Or re-run this script with --publish on a new draft (this deposit is already uploaded)."
fi
