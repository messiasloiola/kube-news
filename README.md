# Kube-News

Uma aplicação de notícias desenvolvida em NodeJS para demonstrar o uso de containers e Kubernetes.

## 📋 Sobre o Projeto

O projeto Kube-News é uma aplicação web simples desenvolvida em Node.js, projetada como exemplo para demonstrar o uso de contêineres. É um portal de notícias que permite criar, visualizar e gerenciar artigos através de uma interface web.

### 🚀 Funcionalidades Principais

- Listagem de notícias na página inicial
- Criação de novas notícias através de formulário
- Visualização detalhada de cada notícia
- API REST para inserção em massa de notícias
- Endpoints de health check para monitoramento
- Coleta de métricas para Prometheus

## 🛠️ Tecnologias Utilizadas

- **Backend**: Node.js com Express.js
- **Frontend**: EJS (Embedded JavaScript) como motor de templates
- **Banco de Dados**: PostgreSQL com Sequelize ORM
- **Monitoramento**: Prometheus (via express-prom-bundle)

## 📦 Estrutura do Projeto

```
/
├── src/                      # Código-fonte principal
│   ├── models/               # Modelos de dados
│   ├── views/                # Templates EJS
│   ├── static/               # Arquivos estáticos (CSS, imagens)
│   ├── middleware.js         # Middlewares personalizados
│   ├── server.js             # Ponto de entrada da aplicação
│   ├── system-life.js        # Endpoints de health check
│   ├── package.json          # Dependências
│   ├── Dockerfile            # Define a imagem Docker da aplicação
│   └── .dockerignore         # Arquivos a serem ignorados pelo Docker
├── docker-compose.yml        # Orquestra os contêineres da aplicação e do banco de dados
├── popula-dados.http         # Arquivo para popular o banco com dados de exemplo
└── README.md                 # Documentação
```

## 🔧 Configuração

### Pré-requisitos

- Node.js e npm (para execução local)
- Docker e Docker Compose (para execução com contêineres)
- PostgreSQL (apenas para execução local sem Docker)

### Variáveis de Ambiente

Para configurar a aplicação, defina as seguintes variáveis de ambiente. Ao usar o `docker-compose.yml`, essas variáveis já são configuradas automaticamente para os contêineres.

| Variável | Descrição | Valor Padrão |
|----------|-----------|--------------|
| DB_DATABASE | Nome do banco de dados | kubedevnews |
| DB_USERNAME | Usuário do banco de dados | kubedevnews |
| DB_PASSWORD | Senha do usuário | Pg#123 |
| DB_HOST | Endereço do banco de dados | localhost |
| DB_PORT | Porta do banco de dados | 5432 |
| DB_SSL_REQUIRE | Habilitar SSL para conexão | false |

## 🚀 Instalação e Execução

### Execução com Docker (Recomendado)

Com o Docker e o Docker Compose instalados, você pode iniciar toda a aplicação (Node.js + PostgreSQL) com um único comando no diretório raiz do projeto:

1.  **Construir e iniciar os contêineres:**
    ```bash
    docker-compose up -d --build
    ```
2.  **Acessar a aplicação:**
    Acesse [http://localhost:8080](http://localhost:8080) no seu navegador.

3.  **Para parar a aplicação:**
    ```bash
    docker-compose down
    ```

### Execução Local (Alternativa)

1. Clone o repositório
2. Instale as dependências:
   ```bash
   cd src
   npm install
   ```
3. Certifique-se de que uma instância do PostgreSQL esteja em execução e configure as variáveis de ambiente necessárias.
4. Inicie a aplicação:
   ```bash
   npm start
   ```
5. Acesse a aplicação em [http://localhost:8080](http://localhost:8080)

### População de Dados de Exemplo

Utilize o arquivo `popula-dados.http` para inserir notícias de exemplo:

```bash
# Com uma ferramenta como o REST Client no VS Code ou curl
POST http://localhost:8080/api/post
Content-Type: application/json
# Conteúdo do arquivo popula-dados.http
```

## 📊 Monitoramento e Health Checks

A aplicação disponibiliza endpoints para monitoramento e também recursos para simular cenários de falha, muito úteis para testar a resiliência em ambientes Kubernetes:

### Endpoints de Monitoramento
- `/health` - Verifica o estado atual da aplicação (retorna status da aplicação e hostname da máquina)
- `/ready` - Verifica se a aplicação está pronta para receber tráfego
- `/metrics` - Métricas do Prometheus (geradas pelo express-prom-bundle)

### Simulação de Falhas (Chaos Engineering)
- `/unhealth` - (PUT) Altera o estado da aplicação para não saudável. Todas as requisições subsequentes receberão status code 500.
- `/unreadyfor/:seconds` - (PUT) Simula indisponibilidade temporária por um número específico de segundos. Durante este período, o endpoint `/ready` retornará status code 500.

Estes recursos de simulação de falhas são extremamente úteis para testar:
- Comportamento de probes de liveness e readiness no Kubernetes
- Políticas de retry e circuit breaker
- Mecanismos de failover
- Resiliência geral da sua infraestrutura

## 🔒 Modelo de Dados

O projeto utiliza um único modelo `Post` com os seguintes campos:

| Campo | Tipo | Descrição |
|-------|------|-----------|
| title | String | Título da notícia (limite: 30 caracteres) |
| summary | String | Resumo da notícia (limite: 50 caracteres) |
| content | String | Conteúdo completo (limite: 2000 caracteres) |
| publishDate | Date | Data de publicação |


