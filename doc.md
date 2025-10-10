  ---

  Projeto Kube-News: Do Zero ao GitOps

  Este documento detalha o processo completo de diagnóstico, correção e automação da aplicação Kube-News, desde a
  organização inicial do projeto até a implementação de um pipeline de CI/CD funcional com GitHub Actions e ArgoCD.

  Fase 1: Organização e Refatoração do Projeto

  O objetivo inicial era preparar o projeto para um pipeline de automação.

  O Problema: Duas Fontes da Verdade

  O projeto continha duas pastas com manifestos Kubernetes:
   1. /kubernetes: Arquivos YAML estáticos.
   2. /chart: Um Helm Chart, que é uma forma de "template" para os arquivos YAML.

  Manter os dois gera inconsistência e duplicação de trabalho.

  A Solução: Padronização com Helm

  Decidimos usar o Helm Chart como a única fonte de verdade.

  > O que é um Helm Chart?
  > Pense no Helm como um "gerenciador de pacotes" para o Kubernetes. Um Chart é um "pacote" que contém tudo que é
  necessário para instalar uma aplicação. Seus componentes principais são:
  >
  > *   Chart.yaml: Um arquivo com metadados sobre o pacote (nome, versão da aplicação, etc.).
  > *   values.yaml: Este é o "painel de controle" do seu Chart. Ele expõe todas as configurações que você pode
  querer mudar (o número de réplicas, a tag da imagem, a porta do serviço, etc.) em um único lugar fácil de editar.
  > *   templates/: Esta é a "fábrica" de manifestos. Os arquivos aqui dentro são os mesmos YAMLs do Kubernetes
  (deployment.yaml, service.yaml), mas com "placeholders" (ex: {{ .Values.replicaCount }}) que são preenchidos com
  os valores do seu arquivo values.yaml.

  Ações Realizadas:
   1. O diretório /kubernetes foi removido.
   2. Focamos em corrigir e melhorar o Helm Chart no diretório /chart.

  Fase 2: A Saga da Depuração (Debugging em Kubernetes)

  Ao tentar implantar o Chart pela primeira vez, encontramos uma série de problemas em cascata. Esta seção detalha
  cada um deles e como foram resolvidos.

  1. Pod do Banco de Dados em Pending

   * Sintoma: O pod do PostgreSQL ficava "preso" no estado Pending e nunca iniciava.
   * Diagnóstico: O comando kubectl describe pod <nome-do-pod> mostrou o evento unbound immediate 
     PersistentVolumeClaims. Isso significa que o pod pedia um disco de armazenamento, mas o cluster não sabia como
     criar um (confirmado pela saída vazia de kubectl get storageclass).
   * Solução (Temporária): Para avançar rapidamente, desabilitamos a necessidade de um disco, editando o
     values-dev.yaml para incluir postgres.persistence.enabled: false. Isso fez o pod usar um armazenamento
     temporário.

  2. Pod da Aplicação em ImagePullBackOff

   * Sintoma: O pod da aplicação kube-news não conseguia baixar a imagem do contêiner.
   * Diagnóstico: O kubectl describe nos deu duas pistas em sequência:
       1. Primeiro, um erro 403 Forbidden, indicando que o repositório da imagem era privado e não tínhamos permissão.
       2. Depois de corrigir a permissão, o erro mudou para NotFound, indicando que a imagem com aquele nome/tag
          específicos não existia.
   * Solução:
       1. Permissão: Criamos um Secret no Kubernetes com um token de acesso do GitHub (PAT) e configuramos o
          values-dev.yaml para usá-lo (imagePullSecrets).
       2. Imagem Correta: Corrigimos o nome do repositório e a tag da imagem no values-dev.yaml para apontar para a
          imagem que realmente existia (ghcr.io/messiasloiola/kube-news:0.1.0).

  3. Pod da Aplicação em CrashLoopBackOff

   * Sintoma: A imagem baixava, mas a aplicação iniciava e quebrava em um loop infinito.
   * Diagnóstico: O comando kubectl logs <nome-do-pod> foi nosso melhor amigo aqui. Ele mostrou o erro password 
     authentication failed for user "kubedevnews".
   * Causa Raiz (A Mais Complexa): Descobrimos uma série de desalinhamentos entre o código da aplicação e a
     configuração do Chart.
       1. Nomes de Variáveis: O código Node.js esperava a variável de ambiente DB_PASSWORD, mas nosso Chart estava
          fornecendo POSTGRES_PASSWORD.
       2. Aspas Inválidas (`| quote`): Em vários pontos, usamos a função | quote nos templates do Helm. Isso
          adicionava aspas extras desnecessárias ('valor') aos valores de configuração, corrompendo o nome do banco de
           dados e a senha.
       3. Senha Não Determinística: O ArgoCD, ao usar o values-dev.yaml que não tinha uma senha definida, fazia com
          que o Helm gerasse uma senha nova e aleatória a cada sincronização, criando instabilidade.
   * Solução Final e Definitiva:
       1. Padronizamos os Nomes: Alteramos o configmap.yaml e o secret.yaml para sempre usarem os nomes que a
          aplicação esperava (DB_DATABASE, DB_USERNAME, DB_PASSWORD).
       2. Mapeamos para o Postgres: Ajustamos o postgres-deployment.yaml para "traduzir" essas variáveis para os nomes
           que o contêiner do PostgreSQL esperava (ex: pegar o valor de DB_PASSWORD e colocar na variável
          POSTGRES_PASSWORD).
       3. Removemos as Aspas: Retiramos todos os | quote dos arquivos de data no ConfigMap e Secret.
       4. Fixamos a Senha: Adicionamos uma senha fixa (admin) no values-dev.yaml para garantir que a implantação do
          ArgoCD fosse estável e previsível.

  Fase 3: Automação com Pipeline de CI/CD

  Com a aplicação finalmente rodando, partimos para a automação.

  Parte 1: CI (Integração Contínua) com GitHub Actions

   * Objetivo: Automatizar a construção e publicação da imagem Docker a cada push na branch main.
   * Como: Criamos o arquivo .github/workflows/ci.yaml. Este workflow:
       1. É acionado a cada push na branch main.
       2. Faz o login no ghcr.io usando um token.
       3. Gera uma tag única para a imagem baseada no hash do commit (ex: eeedf90). Isso é crucial para
          rastreabilidade.
       4. Constrói e publica a imagem.
       5. Conecta o CI ao CD: Em um passo final, o workflow edita o arquivo chart/values-dev.yaml, atualizando a tag
          da imagem para o novo hash, e faz um git push dessa alteração de volta para o repositório.

  Parte 2: CD (Entrega Contínua) com ArgoCD

   * Objetivo: Fazer com que o cluster se atualize sozinho sempre que houver uma alteração no Git.
   * Como:
       1. Instalamos o ArgoCD no cluster.
       2. Criamos o arquivo argocd/app.yaml. Este manifesto diz ao ArgoCD: "Monitore o repositório kube-news. Dentro
          dele, olhe a pasta chart/ e use o arquivo values-dev.yaml para implantar a aplicação no namespace
          kube-news".
       3. Aplicamos este arquivo no ArgoCD.

  Fase 4: Resolução de Problemas do Git

  Durante a configuração do pipeline, encontramos alguns problemas comuns do Git.

   * Problema 1: "Divergent Branches"
       * Causa: Tanto você (localmente) quanto o pipeline (remotamente) estavam fazendo commits na mesma branch,
         criando dois históricos paralelos.
       * Solução: Adotar o git pull --rebase como um passo padrão no seu fluxo de trabalho. Antes de fazer um push,
         sempre sincronize as alterações feitas pelo seu pipeline.

   * Problema 2: Permissões de Arquivo e SSH
       * Causa: Executar comandos git como usuário root, o que bagunçou as permissões dos arquivos na pasta .git e
         usou a configuração de SSH errada.
       * Solução:
           1. Sempre usar o git com seu usuário normal (messias).
           2. Usar sudo chown -R messias:messias . para corrigir a posse dos arquivos.
           3. Configurar corretamente a autenticação do Git (seja via SSH com chaves ou via HTTPS com token).

  ---

  Conclusão Final

  Ao final do processo, o projeto kube-news foi transformado de uma aplicação com configuração duplicada e com
  erros para um sistema robusto, implantado através de um pipeline GitOps moderno e totalmente funcional.

