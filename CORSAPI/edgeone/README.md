# CORSAPI — EdgeOne Edge Functions 版

将 `CORSAPI/_worker.js`（Cloudflare Workers 版）转换为腾讯云 EdgeOne（Makers / EdgeOne Pages）Edge Function 的部署版本。

## 与 Cloudflare 版差异

| 项目 | Cloudflare 版 `_worker.js` | EdgeOne 版本目录 |
| --- | --- | --- |
| 入口 | `export default { fetch(request, env, ctx) }` | `export default async function onRequest(context)`（`context.request` / `context.env`） |
| 路由 | 任意路径（Worker 自动 catch-all） | 需要 `index.js` + `[[default]].js` 两个同内容文件实现 catch-all |
| KV | `env.KV`（workerd） | Makers 环境变量中的 `KV`（作用相同，代码已兼容） |
| 出站请求头 | 可直通 `request.headers` | **必须白名单转发业务头**（content-type/authorization/cookie/user-agent/referer/origin/accept/accept-language/range/x-requested-with/x-forwarded-for）+ 默认浏览器 UA，否则出站 fetch 会被平台终止（`CLOUD_FUNCTION_INVOCATION_FAILED`）或被目标站 Cloudflare 1010 拦截 |
| 执行限制 | Workers 免费版 CPU 10ms / 请求 | **EdgeOne Edge Function CPU 200ms / 请求** |

## ⚠️ Base58 性能修复（重要）

EdgeOne Edge Function 有 **200ms CPU 硬限制**。原 `_worker.js` 的 Base58 编码是逐位 `intVal % 58n` / `intVal / 58n`，对完整版配置（约 8.8KB JSON）耗时约 250ms，**线上直接返回 HTTP 545 `Error return from script`**（TVBox 拉取订阅时报 545 的原因）。

本目录已改用 **radix 58⁸ 分组除法**（每轮大数除法一次产出 8 个字符）：

| 源 | 旧算法（本地 Node） | 新算法（本地 Node） |
| --- | --- | --- |
| `jin18` | 39ms | 7ms |
| `jingjian` | 105ms | 13ms |
| `full` | **247ms ❌（545）** | **30ms ✅** |

编码结果与标准 Base58 完全一致（已通过解码回比对验证）。

## 部署

```bash
cd CORSAPI/edgeone
# 登录/Token 认证后（Makers 控制台 → API Token）
EDGEONE_PAGES_API_TOKEN=<TOKEN> edgeone makers deploy . -n corsapi-overseas -a overseas
```

- 项目名建议 `corsapi-overseas`，区域 `overseas`（全球可用区，不含中国大陆）
- 部署成功后访问示例：`https://corsapi-overseas-<hash>.edgeone.dev/?format=2&source=full`

## 接口

与 Cloudflare 版一致（GET）：

- `/health` — 健康检查
- `/?format=0|1|2|3&source=jin18|jingjian|full` — 订阅生成
  - `format=0` JSON / `1` JSON+代理前缀 / `2` Base58 / `3` Base58+代理前缀
- `/?url=<目标地址>` — CORS 代理转发