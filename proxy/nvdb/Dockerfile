# Cloud Run container for NVDB CORS proxy
FROM node:18-alpine

WORKDIR /usr/src/app
COPY package.json package-lock.json* ./
RUN npm ci --omit=dev || npm i --omit=dev
COPY . .

ENV NODE_ENV=production
ENV PORT=8080
EXPOSE 8080

CMD ["node", "server.js"]
