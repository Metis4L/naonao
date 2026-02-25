---
name: patch-apply-validator
description: 执行补丁（dry-run/apply）、运行基础回归检查，并输出结构化 execution-report。
user-invocable: true
disable-model-invocation: false
---

# Patch Apply Validator

## 输入
- work_order（支持 dry-run/apply）

## 输出
- execution-report（success/partial/failed）
- file_results[]
- blockers[]
- next_actions[]

## 约束
- dry-run 默认优先
- destructive 操作失败时必须停止后续同类操作
- 报告必须逐文件给结果，不允许仅总评
