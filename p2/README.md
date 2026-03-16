# IoT K3s Lab

Vagrant → 2 VM → K3s → 3 apps http-echo → Services → Ingress Traefik.

## Lancer

```bash
make
```

Crée `master` et `worker1`, installe K3s, déploie les 3 apps.

## Prérequis

- `Vagrant` + `VirtualBox`

## Machines

| Nom | IP |
|---|---|
| master | 192.168.56.10 |
| worker1 | 192.168.56.11 |

## Accès

Ajouter dans `/etc/hosts` :

```
127.0.0.1  app1.com app2.com app3.com
```

Puis tester :

```bash
curl http://app1.com:8080   # → Hello from App1
curl http://app2.com:8080   # → Hello from App2
curl http://app3.com:8080   # → Hello from App3
```

## Commandes utiles

```bash
make ssh        # connexion au master
make kubectl    # état du cluster
make rebuild    # détruire et relancer
make clean      # supprimer tout
```

## Fichiers

- [Vagrantfile](Vagrantfile) : VMs + provisioning K3s + déploiement
- [nginx-deployment.yaml](nginx-deployment.yaml) : 3 deployments http-echo
- [service.yaml](service.yaml) : 3 services internes
- [ingress.yaml](ingress.yaml) : routing hostname via Traefik