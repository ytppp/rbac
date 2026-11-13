FROM node:20-alpine

ENV LANG=C.UTF-8 \
    TZ=Asia/Shanghai \
    CHOKIDAR_USEPOLLING=true

WORKDIR /app

# 先安装依赖，利用 Docker 层缓存
COPY package.json ./
# 基础镜像 node:20-alpine 自带 npm 10.8.2，其 Arborist 有解析 bug
# （Cannot read properties of null (reading 'edgesOut')），先升到 11 再装依赖
RUN npm install -g npm@11 --no-audit --no-fund
RUN npm install --no-audit --no-fund

COPY . .

EXPOSE 3000

CMD ["npm", "run", "dev", "--", "--host", "0.0.0.0", "--port", "3000"]
