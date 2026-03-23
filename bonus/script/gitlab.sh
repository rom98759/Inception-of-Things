#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BONUS_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "Installing GitLab resources..."
kubectl apply --validate=false -f "${BONUS_DIR}/confs/gitlab/namespace.yaml"
kubectl apply --validate=false -n gitlab -f "${BONUS_DIR}/confs/gitlab/volume.yaml"
kubectl apply --validate=false -n gitlab -f "${BONUS_DIR}/confs/gitlab/deployment.yaml"
kubectl apply --validate=false -n gitlab -f "${BONUS_DIR}/confs/gitlab/service.yaml"
kubectl apply --validate=false -n gitlab -f "${BONUS_DIR}/confs/gitlab/ingress.yaml"

echo "Waiting for GitLab deployment..."
kubectl wait --for=condition=Available deployment/gitlab -n gitlab --timeout=1200s

echo "Waiting for GitLab HTTP endpoint..."
GITLAB_URL="${GITLAB_URL:-http://localhost:8080/gitlab/}"
http_ready="false"
for _ in $(seq 1 240); do
	status="$(curl -s -o /dev/null -w "%{http_code}" "${GITLAB_URL}" || true)"
	if [[ "${status}" == "200" || "${status}" == "302" ]]; then
		http_ready="true"
		break
	fi
	sleep 5
done

if [[ "${http_ready}" != "true" ]]; then
	echo "GitLab endpoint is not reachable at ${GITLAB_URL} after timeout."
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
		echo "GITLAB_ROOT_PASSWORD cannot contain single quotes."
		exit 1
	fi
	kubectl exec -n gitlab "${pod_name}" -- gitlab-rails runner "u=User.find_by_username('root'); u.password='${password}'; u.password_confirmation='${password}'; u.save!"
fi

echo "${password}" > "${BONUS_DIR}/.gitlab_password"

echo "GitLab available at: ${GITLAB_URL}"
echo "login: root"
echo "password: ${password}"