# skills-manage 构建与安装指南

## 目录

- [环境要求](#环境要求)
- [快速构建](#快速构建)
- [手动分步构建](#手动分步构建)
- [安装运行](#安装运行)
- [磁盘空间说明](#磁盘空间说明)
- [常见问题](#常见问题)

---

## 环境要求

### 必需软件

| 依赖 | 版本要求 | 验证命令 | 获取方式 |
|------|---------|---------|---------|
| **Node.js** | ^18.0 | `node --version` | [nodejs.org](https://nodejs.org) |
| **pnpm** | ^9.0 | `pnpm --version` | `npm install -g pnpm` |
| **Rust** | ^1.85 | `rustc --version` | [rustup.rs](https://rustup.rs) |
| **Visual Studio Build Tools** | 2022 | — | [visualstudio.microsoft.com](https://visualstudio.microsoft.com/visual-cpp-build-tools/) |

### 国内用户加速配置

#### Cargo 镜像（`%USERPROFILE%\.cargo\config.toml`）

```toml
[source.crates-io]
replace-with = "tuna"

[source.tuna]
registry = "https://mirrors.tuna.tsinghua.edu.cn/git/crates.io-index.git"

[registries.crates-io]
protocol = "sparse"
```

如果清华镜像慢，可切换为：

```toml
[source.rustcc]
registry = "https://code.aliyun.com/rustcc/crates.io-index.git"
```

> **注意**：`config.toml` 文件**必须为 UTF-8 无 BOM 编码**，编辑器设置错误会导致 cargo 报错 `TOML parse error`。

#### npm/pnpm 镜像

```bash
pnpm config set registry https://registry.npmmirror.com
```

---

## 快速构建

项目根目录提供了自动化构建脚本 `build-release.bat`，一键完成全部流程：

```bash
# 在项目根目录执行
build-release.bat
```

脚本自动执行：
1. 清理残留的 cargo/rustc 进程
2. 初始化 MSVC 编译环境（vcvars64.bat）
3. 安装项目依赖
4. 一次完成 Rust 编译 + 前端构建 + NSIS 打包
5. 验证输出文件

> **注意**：请直接在 **cmd.exe 终端** 中运行此脚本（双击或在终端执行），
> 不要通过 IDE 或 AI 工具的 shell 执行（它们有超时限制）。Rust 编译阶段
> 可能短暂无输出，这是正常现象，请不要提前关闭窗口。

---

## 手动分步构建

如果需要精细控制，可以手动分步执行：

### 第 1 步：清理旧进程

```bash
taskkill /F /IM cargo.exe 2>nul
taskkill /F /IM rustc.exe 2>nul
```

> **为什么？** 前一次构建如果被中断，cargo 进程可能残留并锁住 build 目录，
> 导致新构建卡在 `Blocking waiting for file lock on build directory`。

### 第 2 步：初始化 MSVC 编译环境

```bash
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
```

> 路径因 VS 版本而异。VS 2022 Community/Professional/Enterprise 也在此路径。
> 不执行此步骤会导致 Rust 找不到 Windows SDK 和 MSVC 链接器。

### 第 3 步：安装前端依赖

```bash
pnpm install
```

### 第 4 步：Tauri 全量构建（Rust + 前端 + 打包）

```bash
call vcvars64.bat
pnpm tauri build --bundles nsis
```

> 这一步同时做三件事：
> 1. 编译 Rust release 二进制（嵌入前端资源）
> 2. 构建前端（TypeScript 编译 + Vite 打包）
> 3. 生成 NSIS 安装程序
>
> `--bundles nsis` 指定生成 NSIS 安装包，无需额外安装 WiX Toolset。
>
> Rust 二进制输出：`src-tauri\target\release\skills-manage.exe`（约 24 MB）
> NSIS 安装包输出：`src-tauri\target\release\bundle\nsis\skills-manage_*-x64-setup.exe`（约 8 MB）

---

## 安装运行

### 方式一：NSIS 安装包（推荐给最终用户）

1. 双击 `skills-manage_0.10.0_x64-setup.exe`
2. 按向导完成安装
3. 从开始菜单或桌面快捷方式启动

### 方式二：免安装直接运行（开发/调试）

```bash
# 启动开发模式（前端热重载）
pnpm tauri dev

# 或直接运行 release 版本
src-tauri\target\release\skills-manage.exe
```

---

## 磁盘空间说明

一个完整的构建需要约 **5-7 GB** 磁盘空间，分布如下：

| 目录 | 典型大小 | 说明 | 能否清理 |
|------|---------|------|---------|
| `src-tauri/target/release/` | ~2.3 GB | Release 构建产物 | ❌ 删除后需重编 |
| `src-tauri/target/debug/` | ~3.2 GB | Debug 构建产物（`cargo check`/`cargo test` 遗留） | ✅ 可安全删除 |
| `node_modules/` | ~600 MB | 前端 npm 依赖 | ✅ 可删除（`pnpm install` 恢复） |
| `%USERPROFILE%\.cargo\registry\` | ~900 MB | Rust 依赖源码和缓存 | ✅ 可删除（网络慢，下同版本会复用） |
| `dist/` | < 1 MB | Vite 前端构建输出 | ✅ 可删除（`pnpm build` 恢复） |

### 磁盘清理命令

```bash
# 清理 debug 构建产物（最值得清理，约 3.2 GB）
rmdir /s /q src-tauri\target\debug

# 清理 node_modules（可选）
rmdir /s /q node_modules

# 清理 Vite 构建输出（可选）
rmdir /s /q dist
```

---

## 常见问题

### Q: 构建卡在 `Blocking waiting for file lock on build directory`

**原因**：前一次 cargo 进程未正常退出，锁住了 build 目录。

**解决**：
```bash
taskkill /F /IM cargo.exe
taskkill /F /IM rustc.exe
# 也可重启终端或任务管理器杀掉残留进程
```

### Q: `pnpm tauri build` 报错找不到 vcvars

**原因**：未初始化 MSVC 编译环境。

**解决**：确保在 `pnpm tauri build` 之前执行过：
```bash
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
```

### Q: Cargo 下载依赖极慢或失败

**原因**：国内网络访问 crates.io 不稳定。

**解决**：配置清华或阿里云镜像（见上方[加速配置](#国内用户加速配置)）。

### Q: `tauri.conf.json` 中的构建标识符冲突

**解决**：如果配置了 `"identifier": "com.skillsmanage.app"` 但编译报 bundle identifier 冲突，
改为类似 `"identifier": "com.skillsmanage.dev"` 避免与已安装版本冲突。

### Q: 前端访问后端 IPC 返回空/错误

**原因**：Tauri dev 模式下前端需要通过 `invoke()` 调用后端命令。
如果直接浏览器打开 `localhost:24200`（Vite 独立端口）而没启动 Tauri，IPC 不可用。

**正确做法**：使用 `pnpm tauri dev` 启动完整应用，或 `pnpm dev` + `pnpm tauri` 分离运行时。
