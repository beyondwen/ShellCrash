# ShellCrash HY2 单节点改造与 OpenWrt 部署说明

## 1. 背景

当前项目是 `ShellCrash`，本质上是一个在 Shell 环境下部署和管理 `mihomo` / `sing-box` 内核的脚本工具，主要用于：

- OpenWrt 路由器
- 旁路由
- Linux 服务器
- Docker 容器

本次改造目标是：

- 支持直接粘贴 `hysteria2://` / `hy2://` 单节点分享链接
- 不依赖在线转换站
- 在 `sing-box` 路线下本地生成可运行配置
- 支持基础分流

---

## 2. 本次改造内容

### 2.1 新增能力

已支持：

- 直接粘贴 `hysteria2://` / `hy2://` 分享链接
- 本地解析以下字段：
  - 地址
  - 端口
  - 密码
  - `alpn`
  - `insecure`
  - `sni` / `peer`
  - `obfs`
  - `obfs-password`
  - `up` / `down`
- 本地生成 `sing-box` 单节点配置
- 基础分流：
  - 私网流量直连
  - 中国流量直连
  - 国外/漏网流量走 HY2

### 2.2 当前限制

当前这版仅支持：

- `sing-box` / `singboxr` 内核
- 单节点 `HY2`
- 基础分流模板

当前未做：

- `mihomo/meta` 的本地 HY2 生成
- 多节点自动分组
- 完整 ACL4SSR / DustinWin 级别的复杂规则分流
- 广告、AI、媒体等专门策略组

---

## 3. 关键文件

### 3.1 本次需要部署到 OpenWrt 的文件

- `scripts/menus/6_core_config.sh`
- `scripts/libs/hy2_uri.sh`
- `scripts/lang/chs/6_core_config.lang`
- `scripts/lang/en/6_core_config.lang`

### 3.2 本次新增的维护文件

- `MAINTAINING_FORK.md`
- `CUSTOM_CHANGELOG.md`
- `HY2_OPENWRT_GUIDE.md`

### 3.3 关键逻辑位置

- `scripts/menus/6_core_config.sh`
  - 菜单入口
  - 识别 `hy2` / `hysteria2` 分享链接
  - 调用本地生成逻辑

- `scripts/libs/hy2_uri.sh`
  - HY2 URI 解析
  - 单节点 `sing-box` 配置生成
  - 基础分流模板生成

---

## 4. 当前支持的基础分流逻辑

本地生成的单节点 HY2 配置现在包含以下基础规则：

- `DIRECT`
- `REJECT`
- `🚀 节点选择`
- `♻️ 自动选择`
- `🀄️ 国内流量`
- `🐟 漏网之鱼`

路由逻辑：

- 私网 IP 直连
- `cn.srs` 命中的中国流量走 `🀄️ 国内流量`
- `🀄️ 国内流量` 默认 `DIRECT`
- 未命中规则的流量走 `🐟 漏网之鱼`
- `🐟 漏网之鱼` 默认走 HY2 节点

也就是说，当前效果是：

- 国内直连
- 国外/漏网走 HY2

---

## 5. 示例链接解析结果

示例：

```text
hysteria2://3b8ee912-7b4f-4b97-8e8a-33b4070c83ba@127.127.127.127:1212?alpn=h3&insecure=1#233boy-hysteria2-127.127.127.127
```

对应字段：

- 协议：`hysteria2`
- 地址：`127.127.127.127`
- 端口：`1212`
- 密码：`3b8ee912-7b4f-4b97-8e8a-33b4070c83ba`
- TLS：启用
- ALPN：`h3`
- 跳过证书校验：启用
- 节点名称：`233boy-hysteria2-127.127.127.127`

---

## 6. OpenWrt 上的临时部署方式

这是最快的可用方式。

### 6.1 先安装官方 ShellCrash

```sh
export url='https://testingcf.jsdelivr.net/gh/juewuy/ShellCrash@master' \
&& wget -q --no-check-certificate -O /tmp/install.sh $url/install.sh \
&& sh /tmp/install.sh \
&& . /etc/profile >/dev/null 2>&1
```

### 6.2 覆盖改过的文件

OpenWrt 上目标路径通常是：

- `/etc/ShellCrash/menus/6_core_config.sh`
- `/etc/ShellCrash/libs/hy2_uri.sh`
- `/etc/ShellCrash/lang/chs/6_core_config.lang`
- `/etc/ShellCrash/lang/en/6_core_config.lang`

Windows 上传示例：

```powershell
scp scripts/menus/6_core_config.sh root@192.168.1.1:/etc/ShellCrash/menus/6_core_config.sh
scp scripts/libs/hy2_uri.sh root@192.168.1.1:/etc/ShellCrash/libs/hy2_uri.sh
scp scripts/lang/chs/6_core_config.lang root@192.168.1.1:/etc/ShellCrash/lang/chs/6_core_config.lang
scp scripts/lang/en/6_core_config.lang root@192.168.1.1:/etc/ShellCrash/lang/en/6_core_config.lang
```

### 6.3 修权限并重启

```sh
chmod +x /etc/ShellCrash/menus/6_core_config.sh
chmod +x /etc/ShellCrash/libs/hy2_uri.sh
/etc/ShellCrash/start.sh restart
```

### 6.4 使用方式

```sh
crash
```

菜单建议路径：

1. 切核心到 `sing-box` 或 `singboxr`
2. 进入配置文件管理
3. 添加提供者
4. 粘贴 `hysteria2://...`
5. 选择“本地生成仅包含此提供者的配置文件”
6. 启动服务

---

## 7. 官方更新是否会覆盖改动

会。

如果继续使用官方在线更新，以下文件大概率会被覆盖：

- `scripts/menus/6_core_config.sh`
- `scripts/libs/hy2_uri.sh`
- `scripts/lang/chs/6_core_config.lang`
- `scripts/lang/en/6_core_config.lang`

所以临时部署方式只适合：

- 先跑通功能
- 手工维护
- 更新后重新覆盖文件

---

## 8. 可持续维护方案

推荐维护方式：

- 建立你自己的 GitHub fork
- 单独维护一个部署分支，例如 `hy2-openwrt`
- OpenWrt 安装和更新都指向你的 fork

### 8.1 推荐分支策略

- `master` 尽量靠近官方
- `hy2-openwrt` 作为实际部署分支

### 8.2 推荐 Git 流程

```bash
git remote rename origin upstream
git remote add origin https://github.com/<你的用户名>/ShellCrash.git
git checkout -b hy2-openwrt upstream/master
```

提交改动：

```bash
git add scripts/libs/hy2_uri.sh scripts/menus/6_core_config.sh scripts/lang/chs/6_core_config.lang scripts/lang/en/6_core_config.lang MAINTAINING_FORK.md CUSTOM_CHANGELOG.md HY2_OPENWRT_GUIDE.md
git commit -m "feat: support local Hysteria2 single-node import for sing-box"
git push -u origin hy2-openwrt
```

### 8.3 与官方同步

```bash
git fetch upstream
git checkout hy2-openwrt
git merge upstream/master
```

同步后重点检查：

- `scripts/menus/6_core_config.sh`
- `scripts/libs/hy2_uri.sh`
- `scripts/lang/chs/6_core_config.lang`
- `scripts/lang/en/6_core_config.lang`

---

## 9. OpenWrt 的长期安装方式

如果已经把代码发布到你自己的 fork 分支，例如 `hy2-openwrt`，建议安装命令改成：

```sh
export url='https://testingcf.jsdelivr.net/gh/<你的GitHub用户名>/ShellCrash@hy2-openwrt' \
&& wget -q --no-check-certificate -O /tmp/install.sh $url/install.sh \
&& sh /tmp/install.sh \
&& . /etc/profile >/dev/null 2>&1
```

这样以后 OpenWrt 上的安装和更新都从你的版本走，而不是官方版本。

---

## 10. 当前建议

如果只是先把功能跑通：

- 用“临时部署方式”
- 先在 OpenWrt 上验证单节点 HY2 是否可用

如果打算长期维护：

- 不要继续用当前损坏的本地 `.git`
- 重新 clone 一份干净的官方仓库
- 把本次改动迁进去
- 建立自己的 fork 和 `hy2-openwrt` 分支
- 后续安装和更新都改走你的 fork

---

## 11. 当前已知问题

- 当前 Windows 环境没有可用的 `sh`
- `wsl` 也不可用
- 当前工作区的 `.git` 已损坏，不能直接作为长期维护仓库使用

因此本次改造是基于项目结构和静态逻辑完成的，没有在本机直接做 OpenWrt shell 端到端实测。

---

## 12. 结论

当前版本已经可以满足“单节点 HY2 在 ShellCrash 上使用”的核心目标：

- 可直接粘贴单节点 HY2 链接
- 可本地生成 `sing-box` 配置
- 可在 OpenWrt 上使用
- 支持基础分流
- 已整理为可持续维护的结构

如果后续在 OpenWrt 上启动失败、导入失败或代理不通，需要结合实际报错继续调试。
