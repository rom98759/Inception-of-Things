# IoT K3s Lab

Vagrant → 2 VM Ubuntu → K3s → NGINX → Service → Ingress.

## Lancer

```bash
make
```

Crée `master` et `worker1`, installe K3s, déploie NGINX.

## Prérequis

- `Vagrant` + `VirtualBox`

## Machines

| Nom | IP |
|---|---|
| master | 192.168.56.10 |
| worker1 | 192.168.56.11 |

## Accès

http://127.0.0.1:8080

## Commandes utiles

```bash
make ssh        # connexion au master
make kubectl    # état du cluster
make rebuild    # détruire et relancer
make clean      # supprimer tout
```

## Fichiers

- [Vagrantfile](Vagrantfile) : VMs + provisioning K3s + déploiement
- [nginx-deployment.yaml](nginx-deployment.yaml) : pod NGINX
- [service.yaml](service.yaml) : exposition interne
- [ingress.yaml](ingress.yaml) : exposition HTTP via Traefik