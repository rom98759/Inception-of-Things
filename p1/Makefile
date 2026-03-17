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
	rm -rf .vagrant
	vagrant global-status --prune

s:
	vagrant ssh $(USERNAME)S

sw:
	vagrant ssh $(USERNAME)SW

label:
	vagrant provision $(USERNAME)S --provision-with label-worker

.PHONY: all up down s sw clean fclean