#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BONUS_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

GITLAB_BASE_URL="${GITLAB_BASE_URL:-http://localhost:8080/gitlab}"
GITLAB_PROJECT_NAME="${GITLAB_PROJECT_NAME:-iot-playground}"
GITLAB_PROJECT_PATH="${GITLAB_PROJECT_PATH:-root/iot-playground}"

PASSWORD_FILE="${BONUS_DIR}/.gitlab_password"
if [[ ! -s "${PASSWORD_FILE}" ]]; then
	echo "GitLab password file missing: ${PASSWORD_FILE}"
	echo "Run script/gitlab.sh first."
	exit 1
fi

ROOT_PASSWORD="$(cat "${PASSWORD_FILE}")"

echo "Bootstrapping GitLab repository for Argo CD..."
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

files_to_publish = {
    "deployment.yaml": os.path.join(bonus_dir, "confs", "dev", "workload", "deployment.yaml"),
    "service.yaml": os.path.join(bonus_dir, "confs", "dev", "workload", "service.yaml"),
    "ingress.yaml": os.path.join(bonus_dir, "confs", "dev", "workload", "ingress.yaml"),
}


def request(method, url, data=None, headers=None):
    req = urllib.request.Request(url, data=data, method=method)
    if headers:
        for key, value in headers.items():
            req.add_header(key, value)
    with urllib.request.urlopen(req, timeout=30) as resp:
        return resp.status, resp.read().decode("utf-8")


def request_json(method, url, payload=None, headers=None):
    body = None
    all_headers = {"Content-Type": "application/x-www-form-urlencoded"}
    if headers:
        all_headers.update(headers)
    if payload is not None:
        body = urllib.parse.urlencode(payload).encode("utf-8")
    status, text = request(method, url, data=body, headers=all_headers)
    return status, json.loads(text)


# 1) OAuth token from root/password.
_, token_payload = request_json(
    "POST",
    f"{base}/oauth/token",
    {
        "grant_type": "password",
        "username": "root",
        "password": root_password,
    },
)
access_token = token_payload["access_token"]
api_headers = {"Authorization": f"Bearer {access_token}"}

# 2) Ensure project exists.
search_url = f"{base}/api/v4/projects?search={urllib.parse.quote(project_name)}"
_, projects_text = request("GET", search_url, headers=api_headers)
projects = json.loads(projects_text)
project_id = None
for p in projects:
    if p.get("path_with_namespace") == project_path:
        project_id = p["id"]
        break

if project_id is None:
    ns, path = project_path.split("/", 1)
    _, created = request_json(
        "POST",
        f"{base}/api/v4/projects",
        {
            "name": project_name,
            "path": path,
            "namespace_id": 1 if ns == "root" else "",
            "visibility": "public",
            "initialize_with_readme": "true",
            "default_branch": "main",
        },
        headers=api_headers,
    )
    project_id = created["id"]

# 3) Upsert manifests in repository root.
for repo_file, local_path in files_to_publish.items():
    with open(local_path, "r", encoding="utf-8") as fh:
        content = fh.read()

    encoded_file = urllib.parse.quote(repo_file, safe="")
    file_api = f"{base}/api/v4/projects/{project_id}/repository/files/{encoded_file}"
    payload = {
        "branch": "main",
        "content": content,
        "commit_message": f"Sync {repo_file} from bonus manifests",
    }

    try:
        request_json("POST", file_api, payload, headers=api_headers)
    except urllib.error.HTTPError as e:
        if e.code != 400:
            raise
        payload["last_commit_id"] = ""
        request_json("PUT", file_api, payload, headers=api_headers)

print(f"GitLab project ready: {project_path}")
print(f"Argo repo URL (cluster): http://gitlab-service.gitlab.svc.cluster.local/gitlab/{project_path}.git")
print(f"Web URL (host): {base}/{project_path}")
PY
