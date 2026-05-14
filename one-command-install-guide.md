# 一键部署脚本做成“命令下载安装执行”的方案

> 重点：你的部署脚本是交互式脚本，会用 `read` 询问域名、密码、是否暴露 Sub2API 等问题。
>
> 所以不要直接用 `curl ... | bash`。
>
> 推荐做法是：先下载到服务器临时文件，再执行。

---

## 1. 推荐最终用户安装命令

假设你的脚本托管地址是：

```text
https://raw.githubusercontent.com/你的用户名/你的仓库/main/deploy-newapi-sub2api.sh
```

用户在服务器上执行：

```bash
curl -fsSL https://raw.githubusercontent.com/你的用户名/你的仓库/main/deploy-newapi-sub2api.sh -o /tmp/deploy-newapi-sub2api.sh \
  && chmod +x /tmp/deploy-newapi-sub2api.sh \
  && sudo bash /tmp/deploy-newapi-sub2api.sh
```

如果服务器默认就是 root 用户，也可以：

```bash
curl -fsSL https://raw.githubusercontent.com/你的用户名/你的仓库/main/deploy-newapi-sub2api.sh -o /tmp/deploy-newapi-sub2api.sh \
  && chmod +x /tmp/deploy-newapi-sub2api.sh \
  && bash /tmp/deploy-newapi-sub2api.sh
```

---

## 2. 为什么不推荐 curl | bash

很多项目会写：

```bash
curl -fsSL https://example.com/install.sh | bash
```

但你的脚本里有很多交互输入，例如：

```bash
read -r -p "请输入 NewAPI 对外域名" DOMAIN_API
```

如果直接管道给 bash：

```bash
curl ... | bash
```

脚本的标准输入会被 curl 的内容占用，`read` 可能读不到用户输入，甚至误读脚本后面的内容。

所以交互式脚本更稳的做法是：

```bash
curl -o /tmp/script.sh URL
bash /tmp/script.sh
```

---

## 3. 你应该怎么托管脚本

最简单方案：GitHub public repo。

### 3.1 创建 GitHub 仓库

例如仓库名：

```text
newapi-sub2api-deploy
```

目录结构建议：

```text
newapi-sub2api-deploy/
  README.md
  deploy-newapi-sub2api.sh
  docs/
    beginner-guide.md
    manual-steps.md
```

把当前脚本放进去：

```text
deploy-newapi-sub2api.sh
```

### 3.2 Raw 地址格式

GitHub raw 地址一般是：

```text
https://raw.githubusercontent.com/用户名/仓库名/main/deploy-newapi-sub2api.sh
```

例如：

```text
https://raw.githubusercontent.com/acme/newapi-sub2api-deploy/main/deploy-newapi-sub2api.sh
```

最终安装命令就是：

```bash
curl -fsSL https://raw.githubusercontent.com/acme/newapi-sub2api-deploy/main/deploy-newapi-sub2api.sh -o /tmp/deploy-newapi-sub2api.sh \
  && chmod +x /tmp/deploy-newapi-sub2api.sh \
  && sudo bash /tmp/deploy-newapi-sub2api.sh
```

---

## 4. 更专业的方式：做一个短安装命令

GitHub raw 地址太长，可以用你自己的域名做短链接。

例如：

```text
https://install.example.com/newapi-sub2api.sh
```

用户执行：

```bash
curl -fsSL https://install.example.com/newapi-sub2api.sh -o /tmp/deploy-newapi-sub2api.sh \
  && chmod +x /tmp/deploy-newapi-sub2api.sh \
  && sudo bash /tmp/deploy-newapi-sub2api.sh
```

你可以用下面任一方式实现短链接：

```text
方案 A：Cloudflare Pages 托管静态脚本
方案 B：GitHub Pages 托管静态脚本
方案 C：自己的服务器 Nginx/Caddy 托管脚本文件
方案 D：对象存储，例如 R2/S3/OSS
```

小白推荐：GitHub raw 就够了，先不要引入更多组件。

---

## 5. 安全一点的安装方式

对用户更负责任的方式是两步：先下载，再查看，再执行。

```bash
curl -fsSL https://raw.githubusercontent.com/你的用户名/你的仓库/main/deploy-newapi-sub2api.sh -o deploy-newapi-sub2api.sh
less deploy-newapi-sub2api.sh
sudo bash deploy-newapi-sub2api.sh
```

这样用户能看到脚本内容。

如果你要面向陌生用户，README 里建议同时提供：

```text
快速安装命令
安全安装命令
卸载/清理命令
备份命令
常见问题
```

---

## 6. 建议给脚本加版本号

在脚本顶部加：

```bash
VERSION="0.1.0"
```

启动时打印：

```bash
echo "NewAPI + Sub2API Deploy Script v${VERSION}"
```

这样用户截图报错时，你知道他用的是哪个版本。

---

## 7. 建议给脚本加 SHA256 校验

如果你公开发布，可以给用户提供校验值。

生成校验：

```bash
sha256sum deploy-newapi-sub2api.sh
```

用户下载后检查：

```bash
sha256sum /tmp/deploy-newapi-sub2api.sh
```

README 里写：

```text
SHA256: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

注意：每次脚本内容改变，SHA256 都会变。

---

## 8. 推荐 README 安装区块

可以直接复制到你的 GitHub README：

```markdown
## 快速安装

在一台全新的 Ubuntu 22.04 / 24.04 服务器上执行：

```bash
curl -fsSL https://raw.githubusercontent.com/你的用户名/你的仓库/main/deploy-newapi-sub2api.sh -o /tmp/deploy-newapi-sub2api.sh \
  && chmod +x /tmp/deploy-newapi-sub2api.sh \
  && sudo bash /tmp/deploy-newapi-sub2api.sh
```

如果你是 root 用户：

```bash
curl -fsSL https://raw.githubusercontent.com/你的用户名/你的仓库/main/deploy-newapi-sub2api.sh -o /tmp/deploy-newapi-sub2api.sh \
  && chmod +x /tmp/deploy-newapi-sub2api.sh \
  && bash /tmp/deploy-newapi-sub2api.sh
```

## 安全安装

如果你想先检查脚本内容：

```bash
curl -fsSL https://raw.githubusercontent.com/你的用户名/你的仓库/main/deploy-newapi-sub2api.sh -o deploy-newapi-sub2api.sh
less deploy-newapi-sub2api.sh
sudo bash deploy-newapi-sub2api.sh
```
```

---

## 9. 如果你坚持要一行 curl | bash

不推荐，但可以改成下面这种形式：

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/你的用户名/你的仓库/main/deploy-newapi-sub2api.sh)"
```

这比 `curl | bash` 更适合交互脚本，因为脚本内容通过 `-c` 传给 bash，标准输入仍然可以保留给终端。

但它仍然有缺点：

```text
脚本太长时可读性差
出错时不好排查
用户无法先检查脚本
shell 引号和特殊字符更容易出问题
```

所以最终还是推荐：

```bash
curl -o /tmp/deploy.sh URL && sudo bash /tmp/deploy.sh
```

---

## 10. 推荐你现在采用的最终方案

你现在最适合这样做：

```text
1. 创建一个 GitHub public 仓库
2. 上传 deploy-newapi-sub2api.sh
3. README 写清楚准备事项
4. 提供下载到 /tmp 再执行的命令
5. 暂时不要做 curl | bash
6. 后续稳定后再做短域名 install.yourdomain.com
```

最终给用户的命令：

```bash
curl -fsSL https://raw.githubusercontent.com/你的用户名/你的仓库/main/deploy-newapi-sub2api.sh -o /tmp/deploy-newapi-sub2api.sh \
  && chmod +x /tmp/deploy-newapi-sub2api.sh \
  && sudo bash /tmp/deploy-newapi-sub2api.sh
```
