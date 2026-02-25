---
name: schema-contract-guard
description: 对 contracts 下的 schema 与样例进行一致性检查，输出通过/失败、字段错误路径与修复建议。
user-invocable: true
disable-model-invocation: false
---

# Schema Contract Guard

## 输入
- schema_path
- sample_files[]

## 输出
- validation_status: pass/fail
- errors[]: {file, json_path, message}
- fix_suggestions[]

## 流程
1. 读取 schema
2. 逐个读取样例文件
3. 按 schema 字段检查（人工或脚本模式）
4. 输出错误定位与修复建议
