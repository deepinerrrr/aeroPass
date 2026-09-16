# aeroPass 自动更新服务器

这个目录提供一个轻量上传服务：

- 用户端读取：`https://aeropass.langlai.top/api/appcast/android`
- 开发者上传页：`https://aeropass.langlai.top/admin`
- 上传 APK 后自动生成清单：版本号、下载地址、文件大小、SHA-256、更新说明

## 本地试运行

```bash
cd server/app-update
npm install
cp .env.example .env
npm start
```

## 在 Alibaba Cloud Linux 4 部署

```bash
sudo dnf install -y nodejs npm nginx
sudo useradd --system --home /opt/aeropass-update --shell /sbin/nologin aeropass || true
sudo mkdir -p /opt/aeropass-update
sudo chown -R "$USER":aeropass /opt/aeropass-update

# 把 server/app-update 目录内的文件复制到 /opt/aeropass-update 后执行：
cd /opt/aeropass-update
npm install --omit=dev
cp .env.example .env
```

把 `.env` 中的 `ADMIN_TOKEN` 改成长随机口令。生产服务使用下面的正式 HTTPS 地址：

```env
PUBLIC_BASE_URL=https://aeropass.langlai.top
```

启动服务：

```bash
sudo cp aeropass-update.service /etc/systemd/system/aeropass-update.service
sudo systemctl daemon-reload
sudo systemctl enable --now aeropass-update
```

如果要用 Nginx 反代：

```bash
sudo cp nginx-aeropass-update.conf /etc/nginx/conf.d/aeropass-update.conf
sudo nginx -t
sudo systemctl enable --now nginx
sudo systemctl reload nginx
```

轻量服务器控制台还需要放行对应端口：

- 直接访问 Node 服务：放行 TCP `8088`
- 使用 Nginx：放行 TCP `80`
- 绑定 HTTPS：额外放行 TCP `443`

Alibaba Cloud Linux 4 默认软件源没有 Certbot，可安装到独立 Python 环境：

```bash
sudo python3 -m venv /opt/certbot
sudo /opt/certbot/bin/pip install --upgrade pip
sudo /opt/certbot/bin/pip install certbot certbot-nginx
sudo /opt/certbot/bin/certbot --nginx \
  -d aeropass.langlai.top \
  --non-interactive --agree-tos \
  --register-unsafely-without-email --redirect
```

启用每天检查、随机延迟执行的自动续期：

```bash
sudo cp certbot-renew.service certbot-renew.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now certbot-renew.timer
sudo /opt/certbot/bin/certbot renew --dry-run
```

## 发布新版本

1. 构建新的 Android APK。
2. 打开 `/admin` 上传页。
3. 填写 `versionName`，例如 `1.0.1`。
4. 填写更大的 `versionCode`，例如当前是 `1`，新版本填 `2`。
5. 上传 APK 并发布。

用户端会根据 `versionCode` 判断是否有新版本。APK 的签名证书必须和用户已安装版本一致，否则 Android 会拒绝覆盖安装。
