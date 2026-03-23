#!/usr/bin/env bash

set -euo pipefail

LOG_STEP=0
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}" .sh | tr '[:lower:]' '[:upper:]')"
exec 3>&1
exec >/dev/null 2>&1

log_info() {
    LOG_STEP=$((LOG_STEP + 1))
    printf '\033[36mINFO\033[0m\033[37m[%04d]\033[0m \033[36m[%s]\033[0m %s\n' "${LOG_STEP}" "${SCRIPT_NAME}" "$1" >&3
}

log_text() {
    printf '%s\n' "$1" >&3
}

trap 'printf "\033[31mERROR\033[0m Echec a la ligne %s\n" "$LINENO" >&3' ERR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BONUS_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

GITLAB_BASE_URL="${GITLAB_BASE_URL:-http://localhost:8080/gitlab}"
GITLAB_PROJECT_NAME="${GITLAB_PROJECT_NAME:-iot-playground}"
GITLAB_PROJECT_PATH="${GITLAB_PROJECT_PATH:-root/iot-playground}"

PASSWORD_FILE="${BONUS_DIR}/.gitlab_password"
if [[ ! -s "${PASSWORD_FILE}" ]]; then
    log_text "GitLab password file missing: ${PASSWORD_FILE}"
    log_text "Run script/gitlab.sh first."
	exit 1
fi

ROOT_PASSWORD="$(cat "${PASSWORD_FILE}")"

log_info "Preparation repository GitLab pour Argo CD"
GITLAB_BASE_URL="${GITLAB_BASE_URL}" \
GITLAB_PROJECT_NAME="${GITLAB_PROJECT_NAME}" \
GITLAB_PROJECT_PATH="${GITLAB_PROJECT_PATH}" \
ROOT_PASSWORD="${ROOT_PASSWORD}" \
BONUS_DIR="${BONUS_DIR}" \
python3 - <<'PY'
import json
import os
import urllib.error
import urllib.parse
import urllib.request

base = os.environ["GITLAB_BASE_URL"].rstrip("/")
project_name = os.environ["GITLAB_PROJECT_NAME"]
project_path = os.environ["GITLAB_PROJECT_PATH"]
root_password = os.environ["ROOT_PASSWORD"]
bonus_dir = os.environ["BONUS_DIR"]
BRANCH = "main"
files_to_publish = [
    ("deployment.yaml", os.path.join(bonus_dir, "confs", "dev", "workload", "deployment.yaml")),
    ("service.yaml", os.path.join(bonus_dir, "confs", "dev", "workload", "service.yaml")),
    ("ingress.yaml", os.path.join(bonus_dir, "confs", "dev", "workload", "ingress.yaml")),
]


def http_json(method, url, payload=None, headers=None, form_urlencoded=False):
    req_headers = headers or {}
    data = None
    if payload is not None:
        if form_urlencoded:
            data = urllib.parse.urlencode(payload).encode("utf-8")
            req_headers = {**req_headers, "Content-Type": "application/x-www-form-urlencoded"}
        else:
            data = json.dumps(payload).encode("utf-8")
            req_headers = {**req_headers, "Content-Type": "application/json"}

    req = urllib.request.Request(url, data=data, method=method)
    for key, value in req_headers.items():
        req.add_header(key, value)

    with urllib.request.urlopen(req, timeout=30) as resp:
        text = resp.read().decode("utf-8")
        return {} if not text else json.loads(text)


token_payload = http_json(
    "POST",
    f"{base}/oauth/token",
    {
        "grant_type": "password",
        "username": "root",
        "password": root_password,
    },
    form_urlencoded=True,
)
api_headers = {"Authorization": f"Bearer {token_payload['access_token']}"}

encoded_project_path = urllib.parse.quote(project_path, safe="")
project_api = f"{base}/api/v4/projects/{encoded_project_path}"

try:
    project = http_json("GET", project_api, headers=api_headers)
except urllib.error.HTTPError as err:
    if err.code != 404:
        raise
    _, project_repo_path = project_path.split("/", 1)
    project = http_json(
        "POST",
        f"{base}/api/v4/projects",
        {
            "name": project_name,
            "path": project_repo_path,
            "visibility": "public",
            "initialize_with_readme": True,
            "default_branch": BRANCH,
        },
        headers=api_headers,
    )

project_id = project["id"]

for repo_file, local_path in files_to_publish:
    with open(local_path, "r", encoding="utf-8") as fh:
        content = fh.read()

    encoded_file = urllib.parse.quote(repo_file, safe="")
    file_api = f"{base}/api/v4/projects/{project_id}/repository/files/{encoded_file}?ref={BRANCH}"
    payload = {
        "branch": BRANCH,
        "content": content,
        "commit_message": f"Sync {repo_file} from bonus manifests",
    }

    try:
        http_json("GET", file_api, headers=api_headers)
        http_json("PUT", file_api, payload, headers=api_headers)
    except urllib.error.HTTPError as err:
        if err.code != 404:
            raise
        http_json("POST", file_api, payload, headers=api_headers)

PY

log_info "Repository GitLab pret"
log_text "Argo repo URL (cluster): http://gitlab-service.gitlab.svc.cluster.local/gitlab/${GITLAB_PROJECT_PATH}.git"
log_text "Web URL (host): ${GITLAB_BASE_URL%/}/${GITLAB_PROJECT_PATH}"
