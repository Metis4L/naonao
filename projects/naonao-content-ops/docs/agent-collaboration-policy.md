# Agent Collaboration Policy（闹闹内容系统）

## 目标
明确 main / technical-advisor / execution-engineer / hard-validator / feedback-router 的职责边界与协作流程，避免重复劳动、越权执行、状态混乱。

---

## 角色与边界

### main
- 用户入口、粗路由
- 不做深度工程决策
- 不直接替代 technical-advisor / execution-engineer

### naonao-technical-advisor（控制面）
负责：
- 需求塑形
- 迭代策略
- 执行单生成
- 报告解读
- 死循环恢复
- 主动推进下一步
- 拥有“推进权”和“建议权”

不负责：
- 直接改文件
- 越权晋升 baseline
- 业务主权变更的最终批准

### execution-engineer（执行面）
负责：
- 文件改动与验证执行
- dry-run/apply/test
- 备份与回报

不负责：
- 自主改目标
- 重新定义策略方向

### naonao-hard-validator（门禁面）
负责：
- 合同与报告校验
- 回归门禁
- baseline guard 执行

不负责：
- 业务补丁设计
- 文件变更执行

### naonao-feedback-router（业务分析面）
负责：
- 改前/改后稿 diff
- 结构化纠错归因
- 规则候选建议（候选）

不负责：
- 直接写入规则库
- 基线晋升决策

---

## 标准流程（推荐）
1. 用户目标 -> technical-advisor（需求收口 + iter计划）
2. technical-advisor -> execution-engineer（执行单）
3. execution-engineer -> technical-advisor（execution-report）
4. technical-advisor -> hard-validator（门禁校验，可选但推荐）
5. technical-advisor -> 用户（结果 + 下一步 + 是否晋升建议）

---

## 卡死恢复流程（必须）
若出现重复追问/硬阻塞：
1. technical-advisor 进入 deadlock-recovery-planner
2. 输出 analysis-only 恢复方案
3. 最多一次提示最小输入格式
4. 仍缺失则进入 awaiting_user_input，不重复催促

---

## 基线保护规则
- 当前 baseline 由基线记录文件定义
- 任何新迭代低于 baseline，不得晋升
- 候选可保留，但必须标记 candidate/rejected
- 生产基线变更需门禁通过 + 人工确认（推荐）

## 最终拍板权（用户）
涉及以下事项必须由用户拍板：
- baseline 晋升
- 核心风格规则变更
- 自动化权限升级
- 跨 agent 边界重构
