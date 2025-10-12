#!/bin/bash
set -e # Encerra o script se um comando falhar

# --- Variáveis de Configuração (Pronto para HA) ---
# Versões fixas para garantir reprodutibilidade.
# Pesquise as versões estáveis mais recentes antes de executar.
export RKE2_VERSION="v1.33.5+rke2r1"          # Ex: Versão estável do RKE2
export RANCHER_CHART_VERSION="2.12.2"       # Ex: Versão estável do Rancher
export CERT_MANAGER_CHART_VERSION="v1.19.0" # Ex: Versão estável do Cert-Manager
export SEALED_SECRETS_CHART_VERSION="2.17.7" # Ex: Versão estável do Sealed Secrets

# --- Configurações do Ambiente ---
# 1. IP do seu nó atual.
export NODE_IP=$(hostname -I | awk '{print $1}')

# 2. O DNS que APONTARÁ PARA O SEU FUTURO LOAD BALANCER.
export RANCHER_HOSTNAME="rancher.${NODE_IP}.nip.io"

# 3. O endereço do SEU FUTURO LOAD BALANCER.
export FUTURE_LB_ADDRESS="${NODE_IP}"

# 4. E-mail para o Let's Encrypt
export LETSENCRYPT_EMAIL="messiasloiolaaws@gmail.com"

echo "--- INICIANDO SETUP DO PRIMEIRO NÓ (PRONTO PARA HA) ---"
echo "Versão do RKE2: ${RKE2_VERSION}"
echo "Versão do Rancher: ${RANCHER_CHART_VERSION}"
echo "Versão do Cert-Manager: ${CERT_MANAGER_CHART_VERSION}"
echo "Versão do Sealed Secrets: ${SEALED_SECRETS_CHART_VERSION}"
echo "----------------------------------------------------"
read -p "Pressione [Enter] para continuar..."

# --- 1. Configuração do Servidor RKE2 (formato HA) ---
echo "--> Configurando RKE2 para futuro HA (sem token pré-definido)..."
sudo mkdir -p /etc/rancher/rke2/
sudo bash -c "cat <<EOF > /etc/rancher/rke2/config.yaml
tls-san:
  - \"${RANCHER_HOSTNAME}\"
  - \"${FUTURE_LB_ADDRESS}\"
EOF"

# --- 2. Instalação do RKE2 Server ---
echo "--> Instalando RKE2 versão ${RKE2_VERSION}..."
curl -sfL https://get.rke2.io | INSTALL_RKE2_VERSION=${RKE2_VERSION} sudo -E sh -

# --- 3. Habilitar e Iniciar o Serviço RKE2 ---
echo "--> Habilitando e iniciando rke2-server..."
sudo systemctl enable rke2-server.service
sudo systemctl start rke2-server.service

# --- 4. Configuração do kubectl e Espera pelo Cluster ---
echo "--> Configurando kubectl..."
while [ ! -f /etc/rancher/rke2/rke2.yaml ]; do
    echo "Aguardando arquivo de configuração do RKE2..."
    sleep 5
done
sleep 10

sudo cp /etc/rancher/rke2/rke2.yaml /tmp/rke2.yaml
sudo chown $USER:$USER /tmp/rke2.yaml
mkdir -p ~/.kube
cp /tmp/rke2.yaml ~/.kube/config
chmod 600 ~/.kube/config

export PATH=$PATH:/opt/rke2/bin:/var/lib/rancher/rke2/bin
echo 'export PATH=$PATH:/opt/rke2/bin:/var/lib/rancher/rke2/bin' >> ~/.bashrc

# Espera robusta para o nó ficar Ready
echo "Aguardando o nó do cluster ficar com o status 'Ready'..."
NODE_NAME=$(kubectl get nodes -o name)
while [[ $(kubectl get $NODE_NAME -o 'jsonpath={.status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do
    echo "Status do nó $NODE_NAME ainda não é 'Ready'. Verificando novamente em 20 segundos..."
    kubectl get nodes
    kubectl get pods -A | grep -i -e pending -e error -e crash
    sleep 20
done
echo "Nó $NODE_NAME está 'Ready'!"

# Adicional: Espera robusta para o webhook do Ingress Controller ficar disponível
echo "Aguardando o webhook do Ingress Controller ter endpoints disponíveis..."
while [ -z "$(kubectl get endpointslice -n kube-system -l kubernetes.io/service-name=rke2-ingress-nginx-controller-admission -o 'jsonpath={.items[*].endpoints[*].addresses[*]}')" ]; do
    echo "Webhook do Ingress Controller ainda não tem endpoints. Verificando pods em kube-system e aguardando 20 segundos..."
    kubectl get pods -n kube-system
    sleep 20
done
echo "Webhook do Ingress Controller está pronto!"

echo "--> Testando comunicação com o cluster:"
kubectl get nodes

# --- 5. Instalação do Helm ---
if ! command -v helm &> /dev/null; then
    echo "--> Instalando Helm..."
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
    chmod 700 get_helm.sh
    ./get_helm.sh
    rm get_helm.sh
fi

# --- 6. Instalação do Cert-Manager e Rancher (com otimização Helm) ---
echo "--> Adicionando repositórios Helm..."
helm repo add jetstack https://charts.jetstack.io
helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets

echo "--> Atualizando repositórios Helm..."
helm repo update

echo "--> Instalando Cert-Manager versão ${CERT_MANAGER_CHART_VERSION}..."
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version ${CERT_MANAGER_CHART_VERSION} \
  --set crds.enabled=true \
  --wait

echo "--> Instalando Sealed Secrets Controller versão ${SEALED_SECRETS_CHART_VERSION}..."
helm install sealed-secrets sealed-secrets/sealed-secrets \
  --namespace kube-system \
  --version ${SEALED_SECRETS_CHART_VERSION} \
  --wait

echo "--> Instalando Rancher versão ${RANCHER_CHART_VERSION}..."
helm install rancher rancher-latest/rancher \
  --namespace cattle-system \
  --create-namespace \
  --version ${RANCHER_CHART_VERSION} \
  --set hostname=${RANCHER_HOSTNAME} \
  --set replicas=1 \
  --set ingress.tls.source=letsEncrypt \
  --set letsEncrypt.email=${LETSENCRYPT_EMAIL} \
  --set ingress.class=nginx \
  --wait

# --- 8. Finalização e Exibição de Tokens ---
echo "--> Aguardando Rancher ficar pronto..."
kubectl -n cattle-system rollout status deploy/rancher

# Extrai e exibe o token do cluster para uso futuro
NODE_TOKEN=$(sudo cat /var/lib/rancher/rke2/server/node-token)

echo "--------------------------------------------------"
echo "✅ Instalação concluída!"
echo "Acesse a UI do Rancher em: https://${RANCHER_HOSTNAME}"
echo ""
echo "Sua senha de bootstrap (gerada automaticamente) é:"
kubectl get secret --namespace cattle-system bootstrap-secret -o go-template='{{.data.bootstrapPassword|base64decode}}' && echo ""
echo ""
echo "**************************************************"
echo "IMPORTANTE: GUARDE ESTE TOKEN PARA ADICIONAR NOVOS NÓS!"
echo "Token do Cluster: ${NODE_TOKEN}"
echo "**************************************************"
