NAME = p1

USERNAME := $(shell whoami)

all: up

up:
	vagrant up

down:
	vagrant halt

clean:
	${RM} k3s_token

fclean: clean
	vagrant destroy -f
	vagrant global-status --prune
	rm -rf .vagrant

s:
	vagrant ssh $(USERNAME)S

sw:
	vagrant ssh $(USERNAME)SW

label:
	vagrant provision $(USERNAME)S --provision-with label-worker

.PHONY: all up down s sw clean fclean