#!/usr/bin/env bash
set -e

DB_HOST="${DB_HOST:-db}"
DB_PORT="${DB_PORT:-5432}"
DB_USER="${DB_USER:-postgres}"

echo "==> 等待 PostgreSQL (${DB_HOST}:${DB_PORT}) 就绪..."
until pg_isready -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" >/dev/null 2>&1; do
  sleep 1
done
echo "==> PostgreSQL 已就绪"

# 绑定的 Windows 目录里可能缺少 Rails 运行时目录
mkdir -p tmp/pids log storage

# tmp/pids 落在挂载目录里，容器被强制重启时 pid 文件会留下来，
# Puma 会因此误判「已有实例在运行」而拒绝启动，这里先清掉
rm -f tmp/pids/server.pid

# 用 ruby 直接执行 binstub，避免 Windows 挂载文件缺失可执行位
echo "==> 检查 Ruby 依赖"
bundle check || bundle install

echo "==> 准备数据库（建库 / 迁移）"
ruby bin/rails db:prepare

echo "==> 写入初始权限、角色与账号"
ruby bin/rails db:seed

echo "==> 启动服务：$*"
exec "$@"
