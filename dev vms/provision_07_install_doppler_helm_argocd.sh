#!/bin/bash
cd ~/interactivebrokers2/Helm
#kubectl delete -f 'namespaces.yaml'
kubectl apply -f 'namespaces.yaml'

echo "Adding Helm repo..."
microk8s helm3 repo add doppler https://helm.doppler.com
microk8s helm3 repo update

echo "Installing Doppler Helm Operator..."
microk8s helm3 upgrade --install doppler-operator doppler/doppler-kubernetes-operator --namespace doppler-operator-system

echo "Installing ArgoCD ..."
kubectl apply -n argocd -f 'https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml'
kubectl config set-context --current --namespace=argocd

# Setting up Doppler service token for ArgoCD
echo "Setting up Doppler service tokens for Paper and Live..."
kubectl delete -n doppler-operator-system secret doppler-service-token-paper --ignore-not-found
kubectl create secret generic doppler-service-token-paper -n doppler-operator-system --from-literal=serviceToken=$DOPPLER_SERVICE_TOKEN_IBKR_PAPER

kubectl delete -n doppler-operator-system secret doppler-service-token-live --ignore-not-found
kubectl create secret generic doppler-service-token-live -n doppler-operator-system --from-literal=serviceToken=$DOPPLER_SERVICE_TOKEN_IBKR_LIVE

# --- Add this block to create a GitHub deploy key secret for ArgoCD ---
echo "Setting up ArgoCD repo access secret..."
if [ ! -s "$HOME/.ssh/id_ed25519" ]; then
  echo "ERROR: $HOME/.ssh/id_ed25519 does not exist or is empty!"
  exit 1
fi

# Create the ArgoCD GitHub SSH secret
export SSH_PRIVATE_KEY_B64=$(base64 -w0 $HOME/.ssh/id_ed25519)
envsubst < argocd-github-ssh.yaml | kubectl apply -f -
envsubst < argocd-ibkr-trading-bot-repository.yaml | kubectl apply -f -

# Create ArgoCD Project
kubectl apply -f argocd-ibkr-trading-bot-project.yaml

# Create ArgoCD App
# kubectl apply -f argocd-ibkr-trading-bot-app.yaml

# Create ArgoCD App Set
kubectl apply -f argocd-ibkr-trading-bot-appset.yaml

# Port-forward ArgoCD server
# kubectl port-forward svc/argocd-server -n argocd 8080:443 &
# kubectl config set-context --current --namespace=argocd

# login password is in secret argocd-initial-admin-secret
# argocd login --username admin --password "$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 --decode)" --insecure --grpc-web localhost:8080
