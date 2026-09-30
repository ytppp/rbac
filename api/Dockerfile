FROM ruby:3.3.5-slim

ENV LANG=C.UTF-8 \
    TZ=Asia/Shanghai \
    RAILS_ENV=development \
    BUNDLE_JOBS=4 \
    BUNDLE_RETRY=3

# libpq-dev / build-essential 用于编译 pg 原生扩展
# postgresql-client 提供 pg_isready，用于等待数据库就绪
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      build-essential \
      libpq-dev \
      postgresql-client \
      curl \
      tzdata && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 先只拷贝 Gemfile，让 gem 安装层可以被 Docker 缓存
COPY Gemfile ./
RUN bundle install

COPY . .

# 启动脚本放到 /usr/local/bin，避免被运行时挂载的 /app 覆盖
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 3000

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0", "-p", "3000"]
