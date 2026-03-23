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

log_info "Installation des ressources GitLab"
kubectl apply --validate=false -f "${BONUS_DIR}/confs/gitlab/namespace.yaml"
kubectl apply --validate=false -n gitlab -f "${BONUS_DIR}/confs/gitlab/volume.yaml"
kubectl apply --validate=false -n gitlab -f "${BONUS_DIR}/confs/gitlab/deployment.yaml"
kubectl apply --validate=false -n gitlab -f "${BONUS_DIR}/confs/gitlab/service.yaml"
kubectl apply --validate=false -n gitlab -f "${BONUS_DIR}/confs/gitlab/ingress.yaml"

log_info "Attente du deployment GitLab"
kubectl wait --for=condition=Available deployment/gitlab -n gitlab --timeout=1200s

log_info "Attente endpoint HTTP GitLab"
GITLAB_URL="${GITLAB_URL:-http://localhost:8080/gitlab/}"
http_ready="false"
http_timeout_seconds="${GITLAB_HTTP_TIMEOUT_SECONDS:-1200}"
poll_interval_seconds="${GITLAB_HTTP_POLL_INTERVAL_SECONDS:-2}"
signin_url="${GITLAB_URL%/}/users/sign_in"
start_time="$(date +%s)"
attempt=0

while :; do
	attempt=$((attempt + 1))
	status_root="$(curl -sS -o /dev/null -w "%{http_code}" --connect-timeout 2 --max-time 4 "${GITLAB_URL}" || true)"
	status_signin="$(curl -sS -o /dev/null -w "%{http_code}" --connect-timeout 2 --max-time 4 "${signin_url}" || true)"

	if [[ "${status_root}" =~ ^[23][0-9][0-9]$ || "${status_root}" == "401" || "${status_root}" == "403" || "${status_signin}" =~ ^[23][0-9][0-9]$ || "${status_signin}" == "401" || "${status_signin}" == "403" ]]; then
		http_ready="true"
		break
	fi

	if (( attempt % 15 == 0 )); then
		log_text "HTTP wait: root=${status_root:-000} signin=${status_signin:-000}"
	fi

	now="$(date +%s)"
	if (( now - start_time >= http_timeout_seconds )); then
		break
	fi

	sleep "${poll_interval_seconds}"
done

if [[ "${http_ready}" != "true" ]]; then
	log_text "GitLab endpoint is not reachable at ${GITLAB_URL} after timeout."
	exit 1
fi

pod_name="$(kubectl get pods -n gitlab -l app=gitlab -o jsonpath='{.items[0].metadata.name}')"
password=""
for _ in $(seq 1 30); do
	password="$(kubectl exec -n gitlab "${pod_name}" -- sh -lc "awk '/Password:/ {print \$2}' /etc/gitlab/initial_root_password" 2>/dev/null || true)"
	if [[ -n "${password}" ]]; then
		break
	fi
	sleep 10
done

if [[ -z "${password}" ]]; then
	password="${GITLAB_ROOT_PASSWORD:-GitlabRoot42!}"
	if [[ "${password}" == *"'"* ]]; then
		log_text "GITLAB_ROOT_PASSWORD cannot contain single quotes."
		exit 1
	fi
	kubectl exec -n gitlab "${pod_name}" -- gitlab-rails runner "u=User.find_by_username('root'); u.password='${password}'; u.password_confirmation='${password}'; u.save!"
fi

echo "${password}" > "${BONUS_DIR}/.gitlab_password"

log_info "GitLab pret"
log_text "url: ${GITLAB_URL}"
log_text "login: root"
log_text "password: ${password}"