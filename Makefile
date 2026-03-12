
all: up
	@echo "Cluster prêt."
	@echo "Ajoutez dans /etc/hosts: 127.0.0.1 app1.com app2.com app3.com"
	@echo "Test: curl http://app1.com:8080 | curl http://app2.com:8080 | curl http://app3.com:8080"

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