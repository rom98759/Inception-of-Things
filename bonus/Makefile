NAME = p3

CLUSTER_NAME ?= iot-cluster

all: up

setup:
	bash ./script/necessary_packages.sh

up: k3d argocd gitlab gitlab-repo dev

k3d:
	bash ./script/k3d.sh

argocd:
	bash ./script/argocd.sh

dev:
	bash ./script/dev.sh

gitlab:
	bash ./script/gitlab.sh

gitlab-repo:
	bash ./script/gitlab_repo.sh

status:
	kubectl get nodes -o wide
	kubectl get pods -A
	kubectl get ingress -A

down:
	k3d cluster delete $(CLUSTER_NAME) || true

fclean: down

.PHONY: all setup up k3d argocd dev gitlab-repo status down fclean