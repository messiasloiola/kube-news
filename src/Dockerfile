# ===== Stage 1: Build =====
# Use uma imagem Node.js oficial e leve baseada em Alpine.
# A versão específica (18) garante builds consistentes.
FROM node:22-alpine AS base

# Crie e defina o diretório de trabalho no contêiner
WORKDIR /usr/src/app

# Copie os arquivos de manifesto de pacotes
# Isso aproveita o cache de camadas do Docker. As dependências só serão reinstaladas se package.json ou package-lock.json mudarem.
COPY package*.json ./

# Instale as dependências de produção
RUN npm ci --only=production

# Copie o restante do código-fonte da aplicação
COPY . .

# ===== Stage 2: Production =====
# Crie uma imagem final menor a partir da base
FROM base

# Crie um usuário e grupo não-root para a aplicação
# Executar como não-root é uma prática de segurança crucial.
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Mude a propriedade dos arquivos da aplicação para o novo usuário
RUN chown -R appuser:appgroup /usr/src/app

# Mude para o usuário não-root
USER appuser

# Exponha a porta em que a aplicação é executada
EXPOSE 8080

# Comando para iniciar a aplicação
# Usa o formato exec para que os sinais do sistema (como SIGTERM) sejam passados corretamente para o processo Node.
CMD [ "node", "server.js" ]
