FROM node:20-alpine

WORKDIR /app

# Установка зависимостей
COPY package.json package-lock.json* ./
RUN npm install

# Копирование кода
COPY . .

# VITE_API_BASE_URL подставляется на лету в dev-режиме
ARG VITE_API_BASE_URL=http://localhost:8000/api/v1
ENV VITE_API_BASE_URL=${VITE_API_BASE_URL}

EXPOSE 5173

CMD ["npm", "run", "dev", "--", "--host", "0.0.0.0", "--port", "5173"]