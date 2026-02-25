# 外部能力接入说明（Integrations / Skills Reuse Plan）

当前策略：先自建核心能力，再逐步接入可复用 skills / agents。

## 目标

让执行工程师 Agent 后续可以灵活调用已有能力，而不是重复造轮子。

---

## 当前状态

- 已知存在项目内 skills（例如写作 skills、feedback-router 相关 skills）
- 但尚未完成统一能力盘点，因此当前版本默认以自建流程为主

---

## 后续接入流程（建议）

1. 盘点可用能力（名称、路径、输入输出）
2. 记录到 ROUTING_MAP / reusable_patterns
3. 判断复用策略：
   - 直接调用
   - 包装调用（加转换层）
   - 不复用（重写）

---

## 能力记录模板

### 能力名：

### 路径：

### 作用：

### 输入要求：

### 输出格式：

### 适用场景：

### 不适用场景：

### 与哪些能力容易冲突：

### 复用策略（直接/包装/不复用）：

---

## 注意事项

- 未确认可调用前，不要假设“已经可用”
- 不要把项目特化 skill 当通用能力强行迁移

---

## 根目录别名映射（新增）
- `openclaw` -> `/home/metis/.openclaw/workspace`
- `naonao_project` -> `/mnt/e/AI/openclaw/workspaces/naonao-pet-content`

说明：执行单默认使用 root_alias，减少绝对路径误写风险。

## 与 naonao-technical-advisor 的协作协议（新增）
- execution-engineer 优先接收来自 technical-advisor 的结构化执行单
- execution-engineer 不负责重新定义迭代目标；若发现目标不清晰，返回 blocking_issues，由 technical-advisor 收口
- execution-engineer 必须回传结构化 execution-report（含 file_results / blocking_issues / next_actions）
- execution-engineer 可提出执行层改进建议，但不越权修改基线晋升规则
