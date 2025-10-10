  Este guia é um passo a passo completo, do zero, para implantar uma nova aplicação em um ambiente de produção
  seguindo as melhores práticas de GitOps que estabelecemos.

  ---

  Guia de Implantação GitOps: Do Código à Produção com Kubernetes

  Este guia é um manual completo para levar uma aplicação web do código-fonte à produção em um cluster Kubernetes,
  utilizando Docker, Helm, GitHub Actions e ArgoCD.

  Fase 0: Pré-requisitos

  Antes de começar, garanta que você tenha:
   * Ferramentas Locais: git, docker, kubectl, helm.
   * Acessos: Uma conta no GitHub, um cluster Kubernetes acessível, um registro de contêineres (como o ghcr.io) e o
     ArgoCD instalado no cluster.

  ---

  Passo 1: "Contêinerizar" a Aplicação

  O primeiro passo é empacotar sua aplicação em uma imagem Docker.

  1.1. Criar o Dockerfile

  Este arquivo é a receita para construir sua imagem. Para uma aplicação Node.js, um Dockerfile de múltiplos
  estágios é uma boa prática, pois cria uma imagem final menor e mais segura.

  Exemplo de `Dockerfile`:

    1 # Estágio 1: Build
    2 # Usa a imagem completa do Node para instalar dependências e compilar assets
    3 FROM node:18-alpine AS builder
    4 WORKDIR /usr/src/app
    5 COPY src/package*.json ./
    6 RUN npm install
    7 COPY src/ .
    8 
    9 # Estágio 2: Produção
   10 # Usa uma imagem enxuta, apenas com o necessário para rodar
   11 FROM node:18-alpine
   12 WORKDIR /usr/src/app
   13 # Copia apenas os artefatos necessários do estágio de build
   14 COPY --from=builder /usr/src/app .
   15 EXPOSE 8080
   16 CMD [ "node", "server.js" ]

  1.2. Criar o .dockerignore

  Este arquivo evita que arquivos desnecessários (como node_modules local) sejam enviados para o Docker, acelerando
   o build.

  Exemplo de `.dockerignore`:
   1 node_modules
   2 npm-debug.log
   3 .git
   4 .gitignore

  1.3. Testar a Imagem Localmente

  Antes de automatizar, garanta que sua imagem funciona.

   1 # 1. Construa a imagem
   2 docker build -t minha-app:local .
   3 
   4 # 2. Rode o contêiner
   5 docker run -p 8080:8080 minha-app:local
  Acesse http://localhost:8080 para confirmar que a aplicação está rodando dentro do contêiner.

  ---

  Passo 2: Empacotar para Kubernetes (Helm Chart)

  Agora, criamos o "pacote de instalação" para o Kubernetes.

  2.1. Criar a Estrutura do Chart

  O Helm facilita a criação de uma estrutura padrão.
   1 helm create meu-chart
  Isso cria uma pasta meu-chart/ com todos os arquivos que precisamos.

  2.2. Customizar o Chart

  Você irá editar principalmente 3 arquivos dentro de meu-chart/:

   1. `values.yaml` (O Painel de Controle):
      Aqui você define tudo que pode ser configurado. É o arquivo mais importante para o GitOps.

      Exemplo de `values.yaml`:

    1     replicaCount: 1
    2 
    3     image:
    4       repository: ghcr.io/seu-usuario/sua-app
    5       pullPolicy: IfNotPresent
    6       tag: "" # Deixamos em branco para ser preenchido pelo pipeline
    7 
    8     service:
    9       type: ClusterIP
   10       port: 80
   11 
   12     # Para produção, use Ingress
   13     ingress:
   14       enabled: true
   15       hosts:
   16         - host: sua-app.seu-dominio.com
   17           paths:
   18             - path: /
   19               pathType: ImplementationSpecific
   20 
   21     # Configurações da sua aplicação
   22     appConfig:
   23       DB_HOST: "postgres-service"
   24       DB_USER: "user"
   25 
   26     # Configuração de recursos é CRUCIAL para produção
   27     resources:
   28       limits:
   29         cpu: 100m
   30         memory: 128Mi
   31       requests:
   32         cpu: 50m
   33         memory: 64Mi

   2. `templates/deployment.yaml` (A Receita do Pod):
      Aqui você garante que as configurações do values.yaml são usadas. Adicione livenessProbe e readinessProbe
  para que o Kubernetes saiba se sua aplicação está saudável. Garanta que a seção envFrom ou env carregue seus
  ConfigMaps e Secrets.

   3. `templates/ingress.yaml` (O Portão de Entrada):
      Para produção, você não usa NodePort. Você usa um Ingress, que age como um roteador inteligente, direcionando
   o tráfego do seu domínio para o serviço da sua aplicação. O template padrão do Helm já vem com um exemplo de
  Ingress.

  2.3. Gerenciamento de Segredos (A Forma Correta)

  Nunca coloque senhas em texto puro no `values.yaml`! Para produção, use uma abordagem segura:
   * Bitnami Sealed Secrets: Você criptografa seu segredo, pode fazer o commit do segredo criptografado no Git, e só
     o ArgoCD no cluster consegue descriptografá-lo.
   * ArgoCD Vault Plugin: Se você usa HashiCorp Vault, o ArgoCD pode puxar os segredos diretamente de lá durante a
     sincronização.

  Para nosso guia, usamos um segredo simples criado manualmente, mas para produção, estude uma das opções acima.

  ---

  Passo 3: Configurar o Pipeline de CI (GitHub Actions)

  3.1. Criar o Arquivo de Workflow

  Crie o arquivo .github/workflows/ci.yaml. Ele será o cérebro da sua automação. O workflow que construímos juntos
  é um template perfeito e reutilizável.

  3.2. Configurar Permissões e Segredos no GitHub

   1. Permissões do Repositório: Vá em Settings > Actions > General e marque "Read and write permissions". Isso é
      necessário para que o pipeline possa fazer o push de volta para o repositório.
   2. Segredo para o Token: Se o token padrão do GitHub falhar (como aconteceu conosco), crie um segredo em Settings >
       Secrets and variables > Actions com o nome GH_PAT e cole seu Personal Access Token com permissão
      packages:write.

  ---

  Passo 4: Configurar a Entrega Contínua (ArgoCD)

  4.1. Estruturar o Repositório para GitOps

   1. Crie um arquivo de valores específico para cada ambiente, por exemplo: chart/values-prod.yaml.
   2. Crie um diretório argocd/ na raiz do projeto.

  4.2. Criar o Manifesto da Aplicação ArgoCD

  Dentro de argocd/, crie o app.yaml. Este arquivo é a declaração que o ArgoCD usará. Ele é um template
  reutilizável, você só precisa mudar o repoURL e o path.

  ---

  Passo 5: O Fluxo de Trabalho do Dia a Dia

  Seu trabalho como desenvolvedor agora segue um ritmo simples e poderoso:

   1. Sincronize: Antes de começar a codificar, sempre execute git pull --rebase. Isso traz as últimas atualizações
      feitas pelo seu pipeline e evita conflitos.
   2. Codifique: Faça suas alterações na aplicação.
   3. Envie: Execute git add ., git commit -m "...", e git push.

  A partir do push, tudo é automático. Você pode acompanhar o progresso na aba "Actions" do GitHub e na UI do
  ArgoCD.

