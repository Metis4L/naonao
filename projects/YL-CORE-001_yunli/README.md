# YL-CORE-001_yunli

通用 TTS 工具项目（核心名：yunli）

## 目录说明
- `yunli-core/`：Qwen3-TTS 核心代码与运行环境
- `shared/models/`：模型权重（所有项目共用，避免重复下载）
- `shared/voices/`：共享音色/参考音频
- `profiles/<project>/`：项目级配置（每个项目可不同）
- `scripts/`：启动、安装、测试脚本
- `logs/`：运行日志

## 推荐架构（通用 + 项目隔离）
- 一套核心安装（yunli-core）
- 多套项目配置（profiles）

这样不用每个项目重复部署；只有配置不同，模型和代码可以共用。

## 当前状态
已创建骨架与脚本模板。
当前机器缺少 `python3.12-venv`，所以还不能完成 Python 虚拟环境初始化。

安装后执行：
```bash
bash scripts/install_qwen3_tts.sh
bash scripts/smoke_test.sh
```
