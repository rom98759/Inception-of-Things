# p3 - K3d + Argo CD

Ce dossier met en place un environnement local Kubernetes avec k3d et Argo CD.

## Concepts essentiels

- K3s: distribution Kubernetes legere.
- K3d: exectute des clusters K3s dans Docker (ideal pour dev local/CI).
- Namespace: segmentation logique des ressources (`argocd`, `dev`).
- Deployment: gere les pods (replicas, rollout, restart).
- Service: expose les pods a l'interieur du cluster.
- Ingress: route HTTP(S) vers les services.
- Argo CD: moteur GitOps qui synchronise l'etat du cluster depuis Git.

## Arborescence utile

- `script/necessary_packages.sh`: installe Docker officiel Debian, kubectl, k3d.
- `script/k3d.sh`: cree/verifie le cluster k3d.
- `script/argocd.sh`: installe Argo CD et son ingress.
- `script/dev.sh`: cree l'Application Argo CD pour l'environnement dev.
- `confs/dev/workload/`: manifests de l'application (deployment/service/ingress).

## Prerequis OS

Docker officiel est supporte pour Debian:
- trixie (13)
- bookworm (12)
- bullseye (11)

Architectures supportees: `amd64`, `armhf`, `arm64`, `ppc64el`.

## Demarrage rapide

```bash
cd p3
make setup
make up
make status
```

`make up` execute:
1. creation du cluster k3d
2. installation Argo CD
3. creation de l'application Argo CD `playground`

L'installation Argo CD utilise:
- `kubectl apply --server-side --force-conflicts`
- le manifest officiel stable par defaut

Vous pouvez pinner une version:

```bash
ARGOCD_MANIFEST_URL="https://raw.githubusercontent.com/argoproj/argo-cd/v3.2.0/manifests/install.yaml" make argocd
```

## Acces

Le cluster expose le load balancer sur:
- `http://localhost:8080` (HTTP)
- `https://localhost:8443` (HTTPS)

### Playground (Application)

- **URL**: `http://localhost:8080/`
- **Response**: `{"status":"ok", "message": "v1"}`

### Argo CD

- **URL**: `https://localhost:8443/argocd`
- **Route via Ingress**: `/argocd` → `argocd-server` service
- Note: Argo CD applique une redirection TLS et utilise HTTPS

## Mot de passe admin Argo CD

Le script `script/argocd.sh` affiche le mot de passe initial.

Pour obtenir le mot de passe actuellement:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
```

## Configuration Argo CD pour GitOps

### Probleme: Application non-synchronisee

L'application Argo CD `playground` pointe vers `https://github.com/rom98759/Inception-of-Things.git`.
Si le repo est prive, Argo CD ne peut pas y acceder sans credentials.

### Solution 1: Configurer un Personal Access Token (recommande)

```bash
# Remplacez YOUR_GITHUB_TOKEN par votre token GitHub personnel
kubectl create secret generic github-credentials \
  -n argocd \
  --from-literal=username=<username> \
  --from-literal=password=YOUR_GITHUB_TOKEN \
  --dry-run=client -o yaml | kubectl apply -f -

# Enregistrez le repo dans Argo CD
argocd repo add https://github.com/rom98759/Inception-of-Things.git \
  --username <username> \
  --password YOUR_GITHUB_TOKEN
```

### Solution 2: Faire le repo public sur GitHub

Si votre fork est prive, mettez-le en public ou utilisez un repo public pour tests.

### Solution 3: Deploiement manuel pour dev

Pour l'instant, les manifests sont appliques manuellement via:

```bash
kubectl apply -f p3/confs/dev/workload/
```

Une fois les credentials configures, Argo CD synchronisera automatiquement les changements depuis Git.

## Verification

```bash
kubectl get nodes -o wide
kubectl get pods -A
kubectl get applications.argoproj.io -n argocd
kubectl get ingress -A
```

## Changer la version de l'app

Modifiez l'image dans `confs/dev/workload/deployment.yaml`, puis commit/push sur `main`.
Argo CD detecte et applique automatiquement le changement.

## Nettoyage

```bash
make down
```
