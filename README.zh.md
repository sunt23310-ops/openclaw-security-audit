<div align="center">

# OpenClaw Security Audit

### 保护你的 OpenClaw，守护你的隐私

[![License](https://img.shields.io/badge/license-MIT-blue?style=for-the-badge)](./LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS-lightgrey?style=for-the-badge&logo=apple)](https://github.com/sunt23310-ops/openclaw-security-audit)
[![Version](https://img.shields.io/badge/version-1.0.0-green?style=for-the-badge)](https://github.com/sunt23310-ops/openclaw-security-audit)

[English](./README.md) | **中文**

</div>

---

## 这是什么？

一个为 [OpenClaw](https://github.com/openclaw/openclaw)（个人 AI 助手平台）设计的综合安全审计工具。它检查你的 OpenClaw 部署中的安全配置问题、凭据暴露和隐私风险。

**此工具默认只读。** 仅当你主动运行修复命令并逐项确认后才会修改系统。

## 快速开始

```bash
git clone https://github.com/sunt23310-ops/openclaw-security-audit.git
cd openclaw-security-audit
./audit.sh
```

## 检查内容

### 6 大安全模块

| 模块 | 检查内容 |
|------|---------|
| **Gateway 网关** | 端口绑定（0.0.0.0 vs localhost）、认证模式、TLS、Token 强度、所有 OpenClaw 端口（18789-18793, CDP 18800-18899） |
| **凭据安全** | `~/.openclaw/` 目录权限、`.env` 文件权限、配置中的明文 API Key、Shell 历史记录泄露、auth-profiles 安全性 |
| **通道安全** | DM 策略（open vs pairing）、`allowFrom: ["*"]` 通配符、群组策略、`requireMention` 设置 |
| **工具与沙箱** | 沙箱模式（off/non-main/all）、`tools.deny` 列表、`denyCommands` 命令黑名单、工具 profile、CDP 端口暴露 |
| **网络安全** | 全端口暴露扫描、出站连接、防火墙状态、IP 泄露检测（本地 + Shodan） |
| **系统安全 (macOS)** | SIP、FileVault、TCC/完全磁盘访问、摄像头/麦克风、屏幕录制、iCloud 同步暴露、Gatekeeper |

### 威胁模型

检查项按照 [OpenClaw 的 MITRE ATLAS 威胁模型](https://trust.openclaw.ai) 组织：

- **侦察** - 端口暴露、IP 是否在扫描数据库中
- **初始访问** - 开放的 DM 策略、弱 Token、allowFrom 通配符
- **凭据暴露** - 明文密钥、宽松的文件权限、历史记录泄露
- **执行** - 沙箱未启用、无命令黑名单、完全工具权限
- **系统安全** - SIP、FileVault、TCC 权限

## 使用方式

### 交互式菜单（推荐）

```bash
./audit.sh
```

### 运行单个检查

```bash
bash checks/gateway.sh        # 网关安全
bash checks/credentials.sh    # 凭据安全
bash checks/channels.sh       # 通道策略
bash checks/tools.sh          # 工具与沙箱
bash checks/network.sh        # 网络暴露
bash checks/system.sh         # macOS 系统安全
```

### 自动修复

```bash
bash fixes/interactive-fix.sh    # 引导式修复菜单
bash fixes/gateway-fix.sh        # 修复网关绑定和 Token
bash fixes/permission-fix.sh     # 修复文件权限
bash fixes/channel-fix.sh        # 修复通道策略
```

### 生成报告

报告保存在 `history/` 目录下，支持 HTML 和 JSON 格式，按 MITRE ATLAS 分类组织。

## 可用修复项

所有修复都需要你明确确认后才会执行：

| 修复项 | 具体操作 |
|-------|---------|
| 绑定网关到 localhost | 设置 `gateway.bind` 为 `127.0.0.1` |
| 生成强 Token | 创建 64 字符随机 Token，设置认证模式为 `token` |
| 修复文件权限 | `~/.openclaw/` 设为 700，`.env` 设为 600，auth-profiles 设为 600 |
| 修复 DM 策略 | 将 `open` DM 策略改为 `pairing` |
| 移除 allowFrom 通配符 | 移除通道配置中的 `["*"]` 条目 |
| 启用 requireMention | 要求群组中 @提及 才响应 |

## 隐私保护

- **默认不会向外部发送任何数据**，除非你明确同意 IP 泄露检测
- IP 泄露检测使用 [Shodan InternetDB](https://internetdb.shodan.io/)（公开 API，无需认证）
- 在发起任何外部请求前都会征求你的同意

## 系统要求

- macOS（系统级检查；网关/凭据/通道检查在 Linux 上也可运行）
- Python 3（用于 JSON5 配置解析）
- OpenClaw 已安装（未安装时会优雅跳过相关检查）

## 运行测试

```bash
bash tests/run-tests.sh
```

## 许可证

MIT License - 详见 [LICENSE](./LICENSE)
