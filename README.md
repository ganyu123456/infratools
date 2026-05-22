# infratools

Linux 基础设施离线安装工具包，适用于无网络或网络受限的生产环境。  
支持 **amd64** 和 **arm64** 两种架构，下载安装包解压后执行 `install.sh` 即可完成安装。

---

## 📦 包含组件

| 组件 | 说明 | 默认版本 |
|------|------|----------|
| **Docker** | 容器运行时，含 containerd / runc | 27.3.1 |
| **Docker Compose** | 多容器编排工具（作为 Docker CLI 插件安装） | 2.32.0 |

> 后续将持续扩充，计划新增：Kubernetes 相关组件、Harbor 镜像仓库、监控组件等。

---

## 🚀 快速安装

### 1. 下载安装包

前往 [Releases](../../releases) 页面，根据服务器架构选择对应安装包：

| 文件 | 适用架构 |
|------|----------|
| `infratools-{version}-amd64.tar.gz` | x86_64 服务器 |
| `infratools-{version}-arm64.tar.gz` | ARM64 / aarch64 服务器 |

```bash
# 示例：下载 amd64 版本
wget https://github.com/<your-org>/infratools/releases/download/v1.0.0/infratools-v1.0.0-amd64.tar.gz
```

### 2. 解压并安装

```bash
tar -xzf infratools-v1.0.0-amd64.tar.gz
cd infratools-v1.0.0-amd64
sudo bash install.sh
```

安装脚本会自动：

- 检测服务器架构（amd64 / arm64）
- 检测组件是否已安装，**已安装的组件自动跳过**，不会重复安装
- 安装缺失的组件并配置 systemd 服务

### 3. 验证安装结果

```bash
docker version
docker compose version
```

---

## 📁 安装包目录结构

```
infratools-{version}-{arch}/
├── install.sh              # 主安装入口（sudo bash install.sh）
├── versions.env            # 组件版本信息
├── README.md
├── packages/
│   └── docker/
│       ├── docker-{version}.tgz    # Docker 静态二进制包
│       └── docker-compose          # Docker Compose 二进制
└── docker/
    └── install.sh          # Docker 模块安装脚本
```

---

## 🔧 构建发布

### 手动触发构建

在 GitHub Actions 页面选择 **Build & Release Infra Offline Packages** 工作流，点击 **Run workflow**，填写以下参数：

| 参数 | 说明 | 示例 |
|------|------|------|
| `release_tag` | 发布版本号 | `v1.0.0` |
| `docker_version` | Docker 版本 | `27.3.1` |
| `compose_version` | Docker Compose 版本 | `2.32.0` |

### 通过 Tag 触发构建

推送版本 Tag 自动触发构建，使用 workflow 中的默认版本：

```bash
git tag v1.0.0
git push origin v1.0.0
```

### 构建产物

CI 自动生成以下文件并发布到 GitHub Releases：

```
infratools-{tag}-amd64.tar.gz
infratools-{tag}-arm64.tar.gz
SHA256SUMS.txt
```

---

## ⚙️ 修改默认组件版本

如需修改 Tag 推送时的默认组件版本，编辑 `.github/workflows/build-release.yml` 中的 `env` 段：

```yaml
env:
  DEFAULT_DOCKER_VERSION: '27.3.1'
  DEFAULT_COMPOSE_VERSION: '2.32.0'
```

---

## 📋 已测试系统

| 操作系统 | 架构 | 状态 |
|----------|------|------|
| Ubuntu 20.04 / 22.04 | amd64 / arm64 | ✅ |
| CentOS 7 / 8 | amd64 | ✅ |
| Debian 10 / 11 | amd64 / arm64 | ✅ |
| Rocky Linux 8 / 9 | amd64 / arm64 | ✅ |

> 要求系统使用 **systemd** 作为服务管理器。

---

## 📄 License

MIT
