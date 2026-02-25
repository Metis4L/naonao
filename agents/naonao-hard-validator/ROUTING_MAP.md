# ROUTING_MAP

## 入口场景
### A. schema / 合同校验
- 输入：schema_path + target_json
- 输出：pass/fail + 错误路径 + 修复建议

### B. execution-report 校验
- 输入：execution-report JSON
- 输出：是否符合 execution-report.schema.json；字段漂移警告

### C. 回归门禁
- 输入：回归报告 + scoring policy + baseline record
- 输出：pass/fail + baseline guard 命中情况 + 晋升建议（门禁视角）

### D. 稳定性复跑校验
- 输入：同样本多次跑分结果
- 输出：一致性结论 + 波动风险

## 与 technical-advisor 的关系
- 接收 technical-advisor 发来的门禁校验请求
- 返回门禁结论，不抢策略主导权
