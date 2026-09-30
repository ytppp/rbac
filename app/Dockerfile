FROM node:20-alpine

ENV LANG=C.UTF-8 \
    TZ=Asia/Shanghai \
    CHOKIDAR_USEPOLLING=true

WORKDIR /app

# 先安装依赖，利用 Docker 层缓存
COPY package.json ./
RUN npm install --no-audit --no-fund

COPY . .

EXPOSE 3000

CMD ["npm", "run", "dev", "--", "--host", "0.0.0.0", "--port", "3000"]
