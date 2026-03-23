# bonus - K3d + Argo CD + GitLab local

Ce dossier ajoute GitLab local a la stack de la partie 3.

## Objectif

- garder la stack P3 fonctionnelle (k3d + Argo CD + app dev)
- deployer GitLab dans un namespace dedie `gitlab`
- exposer GitLab localement via ingress

## Lancement

```bash
cd bonus
make setup
make up
make status
```

`make up` execute:
1. creation du cluster k3d
2. installation Argo CD
3. deploiement environnement dev
4. deploiement GitLab

Le load balancer k3d est expose sur `http://localhost:8080`.

## URLs

- Playground: `http://localhost:8080/`
- Argo CD: `http://localhost:8080/argocd`
- GitLab: `http://localhost:8080/gitlab/`

## Notes GitLab

- image utilisee: `gitlab/gitlab-ce:latest`
- configuration relative URL root: `/gitlab`
- namespace: `gitlab`
- PVC: `gitlab-volume`

Le script `script/gitlab.sh` sauvegarde le mot de passe root initial dans:

```bash
bonus/.gitlab_password
```

## Verification rapide

```bash
kubectl get pods -A
kubectl get ingress -A
kubectl get svc -n gitlab
kubectl get deploy -n gitlab
```

## Nettoyage

```bash
make down
```
