# ingress-nginx 技术债分析报告

> **分析日期：** 2026-05-29  
> **修订日期：** 2026-09-16（逐条核实全部论断，修正文件路径、统计口径与总量数字）  
> **项目：** [baranchen/ingress-nginx](https://github.com/baranchen/ingress-nginx) — 社区维护 Fork  
> **基线版本：** NGINX 1.30.2（上游 kubernetes/ingress-nginx 已于 2026 年 3 月退休）

---

## 目录

- [1. 背景](#1-背景)
- [2. 架构级债务](#2-架构级债务)
- [3. 代码质量问题](#3-代码质量问题)
- [4. 已知 Bug](#4-已知-bug)
- [5. 生产代码中的 TODO/FIXME](#5-生产代码中的-todofixme)
- [6. 废弃与遗留代码](#6-废弃与遗留代码)
- [7. 测试覆盖缺口](#7-测试覆盖缺口)
- [8. 依赖健康度](#8-依赖健康度)
- [9. 安全压制](#9-安全压制)
- [10. 修复优先级与行动计划](#10-修复优先级与行动计划)

---

## 1. 背景

上游 kubernetes/ingress-nginx 于 2026 年 3 月正式退休，退休原因可归纳为三点：

1. **维护者不足** — 核心志愿者长期超负荷，最终 burnout
2. **技术债过重** — 债务积累导致 CVE 响应周期越来越长
3. **安全风险攀升** — 累积的技术债使及时修补安全漏洞变得不现实

本 Fork 的定位是**过渡方案**，在社区迁移至 Gateway API 之前提供持续的安全更新和 NGINX 版本升级。技术债的清理将直接影响本项目的可持续性和用户信任度。

---

## 2. 架构级债务

### 2.1 nginx.tmpl — 巨型单一模板

| 指标 | 值 |
|------|-----|
| 文件路径 | `rootfs/etc/nginx/template/nginx.tmpl` |
| 总行数 | 1,491 |
| 模板指令数 | 962（`{{` 出现次数） |
| 子模板 | 0（全部内联） |

整个 `nginx.conf` 由一个 Go 模板文件生成，没有任何模块化拆分。任何对配置结构的修改都需要在近 1,500 行的模板中定位正确的位置，修改风险极高。

**影响：** 无法安全地重构 NGINX 配置生成逻辑，是功能扩展和安全修补的主要瓶颈。

### 2.2 Go + Lua 双语言耦合

| 指标 | 值 |
|------|-----|
| Lua 文件数 | 55 |
| Lua 代码总行数 | 6,096 |
| 所在目录 | `rootfs/etc/nginx/lua/` |

Go 控制器与 Lua 运行时之间通过 NGINX 共享内存区（`lua_shared_dict`）进行数据交换，没有跨语言的类型检查或集成测试。任何一侧的接口变更都可能在运行时才暴露问题。

**影响：** 维护者需要同时精通 Go 和 Lua 才能安全修改核心逻辑；调试跨语言问题极其困难。

### 2.3 Annotation 滥用（安全根源）

`nginx.ingress.kubernetes.io/*` 系列注解允许用户向 NGINX 配置注入任意指令。这种设计将 Kubernetes API Server 的信任边界延伸到了数据平面，是 **IngressNightmare CVE (CVE-2025-1974, CVSS 9.8)** 的根本原因。

**影响：** 即使修补了特定 CVE，只要注解注入机制存在，类似攻击面就持续暴露。

---

## 3. 代码质量问题

### 3.1 巨型 "God Object" 文件

| 文件 | 行数 | 函数/方法数 | 职责数 |
|------|------|------------|--------|
| `internal/ingress/controller/controller.go` | 1,921 | 27 | 控制器主循环、后端选择、注解处理、配置同步 |
| `internal/ingress/controller/template/template.go` | 1,721 | 59 | 模板渲染、数据转换、格式化 |
| `internal/ingress/controller/store/store.go` | 1,257 | 28 | K8s 资源监听、缓存、事件分发 |
| `internal/ingress/controller/nginx.go` | 1,150 | 19 | NGINX 进程管理、配置测试、重载 |
| `internal/ingress/controller/config/config.go` | 980 | 4 structs, ~196 fields | 全量配置定义 |

### 3.2 `interface{}` 泛滥

`template.go` 的 59 个模板函数中有 34 个接受 `interface{}` 参数（另有 1 个内联注册的辅助函数，合计 35 处），依赖运行时类型断言：

```go
// 典型模式（34 处）
func formatInt(v interface{}) string {
    return strconv.Itoa(toInt(v))  // 运行时才知类型是否正确
}
```

**影响：** 丧失编译期类型安全，类型错误只能在运行时暴露，增加调试成本。

### 3.3 圈复杂度超标

gocyclo 阈值在 `.golangci.yml` 中直接配置为 40（正常项目使用 10-15），另有 7 个函数通过 `//nolint:gocyclo` 逐个豁免（cmd/ + internal/ 范围内 6 处：生产 4 + 测试 2）：

- `controller.go:getBackendServers`（:729）— 最复杂的函数之一，负责后端服务器选择和排序
- 其他豁免位置：`store/store.go:249`、`template/configmap.go:96`、`annotations/authreq/main.go:313`、`pkg/apis/ingress/types_equals.go:339`（生产代码），以及 `store_test.go:81`、`controller_test.go:1653`（测试代码）

### 3.4 `klog.Fatalf` 滥用

共 **21 处** `klog.Fatalf` 调用，分布在：

| 文件 | 调用数 |
|------|--------|
| `internal/ingress/controller/nginx.go` | 7 |
| `internal/net/ssl/ssl.go` | 5 |
| `cmd/nginx/main.go` | 5 |
| `cmd/nginx/logger.go` | 2 |
| `internal/ingress/controller/status.go` | 1 |
| `cmd/dataplane/main.go` | 1 |

每个 `klog.Fatalf` 都会调用 `os.Exit(1)`，**绕过所有 `defer` 语句**，导致资源泄漏（文件句柄、网络连接、临时文件等）。

---

## 4. 已知 Bug

### `IsRiskyAnnotationError()` 检查了错误的类型

**文件：** `internal/ingress/errors/errors.go:149-151`

```go
// 当前代码（BUG）
func IsRiskyAnnotationError(e error) bool {
    _, ok := e.(ValidationError)      // ← 应为 RiskyAnnotationError
    return ok
}
```

**影响：** 危险注解的错误类型判断逻辑错误，可能导致本应被拦截的危险注解未被正确处理。

---

## 5. 生产代码中的 TODO/FIXME

以下标注存在于生产代码中（不含测试文件），全部确认仍存在：

| # | 文件 | 行号 | 注释内容 |
|---|------|------|----------|
| 1 | `internal/ingress/controller/certificate.go` | 30 | `TODO: Remove this helpers in the future.` |
| 2 | `internal/ingress/controller/controller.go` | 446 | `TODO: Implement sandboxing so this test can be done safely` |
| 3 | `internal/ingress/controller/controller.go` | 1351 | `TODO: Redirect and rewrite can affect the catch all behavior, skip for now` |
| 4 | `internal/ingress/controller/nginx.go` | 279 | `TODO: For now, as the IngressClass logics has changed...` |
| 5 | `internal/ingress/controller/nginx.go` | 367 | `TODO: is this necessary? Consider removing this special case` |
| 6 | `internal/ingress/controller/nginx.go` | 486 | `TODO: Allow PassthroughBackends to specify they support proxy-protocol` |
| 7 | `internal/ingress/controller/template/template.go` | 766 | `TODO: add support for custom protocols` |
| 8 | `internal/ingress/controller/store/store.go` | 584 | `TODO: In a future we might interested in parse parameters...` |
| 9 | `internal/ingress/annotations/parser/main.go` | 103 | `TODO: We already parse all of this on checkAnnotation...` |
| 10 | `internal/ingress/metric/collectors/socket.go` | 74 | `TODO: DEPRECATED, remove` |
| 11 | `internal/nginx/main.go` | 34 | `TODO: Check ports already being used` |
| 12 | `cmd/dbg/main.go` | 231 | `TODO: refactor to obtain ingress-nginx pod count from the api server` |
| 13 | `cmd/dataplane/main.go` | 68 | `TODO: Ingress class is not a part of dataplane anymore` |
| 14 | `cmd/dataplane/main.go` | 76 | `TODO: Dataplane does not contain validation webhook...` |
| 15 | `cmd/nginx/main.go` | 180 | `TODO: remove after k8s v1.22` |

> 注：第 15 条标注 "remove after k8s v1.22"，而当前 k8s 最新版已远超 v1.22，说明该 TODO 已过期很久。

---

## 6. 废弃与遗留代码

### 6.1 已废弃的配置字段

`internal/ingress/controller/config/config.go` 中仍保留 3 个已废弃的 HTTP/2 字段：

- `HTTP2MaxFieldSize`（行 228-229）— 标注 "Deprecated"
- `HTTP2MaxHeaderSize`（行 233-234）— 标注 "Deprecated"
- `HTTP2MaxRequests`（行 240-241）— 标注 "Deprecated"

### 6.2 已废弃的注解

`controller.go` 行 290-309 维护了一份废弃注解列表，这些注解仍会被处理并发出警告，但从未移除。

### 6.3 已废弃的 Ingress Class 注解

`internal/ingress/controller/ingressclass/ingressclass.go:40` 标注 "The Annotation is deprecated and should not be used in future releases"，但代码仍保留。

### 6.4 Legacy Canary 行为

`internal/ingress/annotations/sessionaffinity/main.go:88` 仍接受 `"legacy"` 作为有效的 `CanaryBehavior` 值。

### 6.5 废弃的证书验证逻辑

`controller.go:1483` 标注 "Validating certificate against DNS names. This will be deprecated in a future version"。

---

## 7. 测试覆盖缺口

### 7.1 无测试覆盖的源文件

共 **41 个** Go 源文件没有对应的测试文件（internal/ 21 个 + cmd/ 20 个，其中 16 个集中在 cmd/plugin/），关键未测模块包括：

- **Store 层（文件级缺口）** — store/ 目录 12 个生产文件中 8 个无同名测试（核心 `store.go` 已有 1600+ 行基于 envtest 的测试，并非零测试）
- **Admission Webhook（HTTP 层）** — `server.go` 无测试；核心校验逻辑 `HandleAdmission` 已由 `main_test.go` 覆盖
- **证书管理** — TLS 证书加载和验证逻辑（`certificate.go` 确无任何测试）

### 7.2 测试中标注的 TODO

`internal/ingress/controller/template/template_test.go:59` 明确标注：

```go
// TODO: add tests for SSLPassthrough
```

---

## 8. 依赖健康度

| 依赖 | 问题 | 严重性 |
|------|------|--------|
| `golang.org/x/crypto` | v0.49.0 落后最新 v0.57.0 共 8 个小版本，存在影响 v0.49.0 的已知 CVE（如 GHSA-5cgq-3rg8-m6cv / GHSA-rm3j-f69w-wqmq，fixed 0.52.0）；但仓库内仅 test/e2e 测试代码引用，生产代码未直接使用 | 🟡 中 |
| `gojsondiff` | 自 2018 年 5 月起无代码提交、停止维护（仓库实际未归档）；用于 `test/e2e/framework/httpexpect/object.go` | 🟡 中 |
| gosec 规则压制 | G204（子进程执行）被 `//nolint:gosec` 抑制（9 处，生产 4 处）；G304 等规则在 `Makefile` gosec 目标中全局 exclude | 🟡 中 |

---

## 9. 安全压制

cmd/ + internal/ 全仓库共约 **76 处** `nolint`/`nosec` 规则压制（生产代码约 50 处、测试代码约 26 处），重点文件分布：

| 文件 | 压制数 | 涉及规则 |
|------|--------|----------|
| `controller/controller.go` | 8 | gocyclo（:729）等 |
| `internal/net/ssl/ssl.go` | 6 | gosec（文件权限类，:211/:234/:252） |
| `controller/template/template.go` | 3 | nosec(sha1)×2、gocritic×1 |
| `controller/nginx.go` | 5 | gocritic×2、nosec×1、gosec(G109, G204) |

> 这些压制不一定是误报，应当逐一审查，确认风险可接受或通过重构消除。

---

## 10. 修复优先级与行动计划

### P0 — 立即修复（低难度，高收益）

| # | 项目 | 难度 | 预估工时 | 状态 |
|---|------|------|----------|------|
| 1 | 修复 `IsRiskyAnnotationError()` — 将 `ValidationError` 改为 `RiskyAnnotationError` | 低 | 5 min | ⬜ 未开始 |
| 2 | 升级 `golang.org/x/crypto` 到最新版 | 低 | 15 min | ⬜ 未开始 |

### P1 — 短期改善（中等难度，影响安全）

| # | 项目 | 难度 | 预估工时 | 状态 |
|---|------|------|----------|------|
| 3 | 为 Admission Webhook 补充单元测试和集成测试 | 中 | 2-3 天 | ⬜ 未开始 |
| 4 | 拆分 `nginx.tmpl` 为功能子模板（upstream、server、location 等） | 高 | 1-2 周 | ⬜ 未开始 |

### P2 — 中期重构

| # | 项目 | 难度 | 预估工时 | 状态 |
|---|------|------|----------|------|
| 5 | 将 `template.go` 中 59 个 `interface{}` 函数替换为类型化/泛型参数 | 高 | 1-2 周 | ⬜ 未开始 |
| 6 | 清理全部废弃代码和过期 TODO（移除 k8s v1.22 兼容代码等） | 低 | 1-2 天 | ⬜ 未开始 |
| 7 | 将 `klog.Fatalf` 替换为可测试的错误返回模式 | 中 | 2-3 天 | ⬜ 未开始 |

### P3 — 长期规划

| # | 项目 | 难度 | 预估工时 | 状态 |
|---|------|------|----------|------|
| 8 | 替换归档依赖 `gojsondiff` | 中 | 0.5 天 | ⬜ 未开始 |
| 9 | 审查并消除 22 处安全规则压制 | 中 | 2-3 天 | ⬜ 未开始 |
| 10 | 评估 Lua → 纯 Go 迁移的可行性 | 高 | 需评估 | ⬜ 未开始 |

---

## 附录：技术债度量汇总

| 类别 | 数量 |
|------|------|
| 架构级问题 | 3 |
| 巨型文件（>800 行） | 5 |
| 生产代码 TODO | 15 |
| 废弃代码段 | 5 |
| 无测试源文件 | 41 |
| 安全规则压制 | ~76（重点文件 22） |
| `klog.Fatalf` 调用 | 21 |
| 已知 Bug | 1 |
| 停止维护依赖 | 1 |
