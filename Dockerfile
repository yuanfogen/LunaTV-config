# ---- 第 1 阶段：安装依赖 ----
FROM node:22-alpine AS deps

# 启用 corepack 并激活 pnpm（Node20 默认提供 corepack）
RUN corepack enable && corepack prepare pnpm@latest --activate

WORKDIR /app

# 仅复制依赖清单，提高构建缓存利用率
COPY package.json pnpm-lock.yaml ./

# 清理任何潜在的缓存并安装所有依赖（包括可选的原生模块）
RUN pnpm store prune && pnpm install --frozen-lockfile

# ---- 第 2 阶段：构建项目 ----
FROM node:22-alpine AS builder
# 安装构建工具以编译原生模块
RUN apk add --no-cache python3 make g++
RUN corepack enable && corepack prepare pnpm@latest --activate
WORKDIR /app

# 在构建阶段设置 DOCKER_BUILD，启用 standalone 输出
ENV DOCKER_BUILD=true

# ---- 第 3 阶段：生成运行时镜像 ----
FROM node:22-alpine AS runner

WORKDIR /app

EXPOSE 3000

# 使用自定义启动脚本，先预加载配置再启动服务器
CMD ["node", "start.js"] 
