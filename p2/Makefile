NAME = p2

USERNAME := $(shell whoami)

all: up
	@echo "192.168.56.110 app1.com app2.com app3.com" | sudo tee -a "/etc/hosts"

up:
	vagrant up

down:
	vagrant halt

clean:
	${RM} k3s_token

fclean: clean
	vagrant destroy -f
	vagrant global-status --prune
	${RM} -rf .vagrant

s:
	vagrant ssh $(USERNAME)S

.PHONY: all up down s clean fclean