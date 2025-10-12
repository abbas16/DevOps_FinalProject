FROM node:18-alpine
WORKDIR /app
COPY package.json package.json
# install deps inside container if any (best-effort)
RUN npm ci --only=production || true
COPY . .
EXPOSE 80
CMD ["node","index.js"]
