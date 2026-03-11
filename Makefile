
all: up
	@echo "Cluster prêt. Test: http://127.0.0.1:8080"

up:
	vagrant up

rebuild:
	vagrant destroy -f && vagrant up

destroy:
	vagrant destroy -f

clean: destroy
	rm -rf .vagrant node-token

status:
	vagrant status

ssh:
	vagrant ssh master

kubectl:
	vagrant ssh master -c "sudo KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl get nodes,pods,svc,ingress -A"

.PHONY: all up rebuild destroy clean status ssh kubectl