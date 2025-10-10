# ---- Estágio 1: Build ----
# Usa a imagem completa do Node para instalar as dependências
FROM node:18-alpine AS builder

WORKDIR /usr/src/app

# Copia os arquivos de pacote e usa 'npm ci' para uma instalação limpa e reprodutível
COPY src/package*.json ./
RUN npm ci

# Copia o resto do código-fonte da aplicação
COPY src/ .


# ---- Estágio 2: Produção ----
# Inicia de uma imagem base limpa para um resultado final enxuto
FROM node:18-alpine

WORKDIR /usr/src/app

# Cria um grupo e um usuário não-root para rodar a aplicação com segurança
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Copia apenas os artefatos necessários do estágio de 'builder'
COPY --from=builder /usr/src/app .

# Muda o dono dos arquivos para o novo usuário
USER appuser

EXPOSE 8080

CMD [ "node", "server.js" ]