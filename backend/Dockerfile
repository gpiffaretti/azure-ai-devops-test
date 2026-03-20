FROM node:20-alpine

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm install --frozen-lockfile --production --no-audit --no-fund

COPY src/ ./src/

ENV PORT=8080
EXPOSE 8080

CMD ["node", "src/index.js"]
