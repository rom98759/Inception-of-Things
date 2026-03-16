all: up

up:
	vagrant up

down:
	vagrant halt

clean:
	vagrant destroy -f && rm -rf node-token .vagrant

re: clean up

status:
	vagrant status

ssh-server:
	vagrant ssh rcaillieS

ssh-worker:
	vagrant ssh rcaillieSW

.PHONY: all up down clean re status ssh-server ssh-worker
