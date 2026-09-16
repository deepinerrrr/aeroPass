const crypto = require("crypto");
const fs = require("fs");
const path = require("path");
const express = require("express");
const multer = require("multer");

const app = express();
const port = Number(process.env.PORT || 8088);
const publicBaseUrl = (
  process.env.PUBLIC_BASE_URL || "https://aeropass.langlai.top"
).replace(/\/$/, "");
const adminToken = String(process.env.ADMIN_TOKEN || "");
const storageDir = process.env.STORAGE_DIR || path.join(__dirname, "storage");
const releaseDir = path.join(storageDir, "releases");
const manifestPath = path.join(storageDir, "android-manifest.json");
const tempDir = path.join(storageDir, "tmp");

fs.mkdirSync(releaseDir, { recursive: true });
fs.mkdirSync(tempDir, { recursive: true });

if (adminToken.length < 20 || adminToken.includes("replace-") || adminToken.includes("change-this")) {
  throw new Error("ADMIN_TOKEN 必须配置为至少 20 个字符的随机口令");
}

const upload = multer({
  dest: tempDir,
  limits: { fileSize: 400 * 1024 * 1024 },
  fileFilter: (_req, file, cb) => {
    if (file.originalname.toLowerCase().endsWith(".apk")) {
      cb(null, true);
    } else {
      cb(new Error("只支持上传 APK 文件"));
    }
  },
});

app.use(express.json());
app.use("/admin", express.static(path.join(__dirname, "public")));

app.get("/", (_req, res) => {
  res.redirect("/admin");
});

app.get("/api/health", (_req, res) => {
  res.json({ ok: true, service: "aeropass-update-server" });
});

app.get("/api/appcast/android", (_req, res) => {
  const manifest = readManifest();
  if (!manifest) {
    res.status(204).end();
    return;
  }
  res.json(manifest);
});

app.get("/downloads/:fileName", (req, res) => {
  const safeName = path.basename(req.params.fileName);
  const filePath = path.join(releaseDir, safeName);
  if (!fs.existsSync(filePath)) {
    res.status(404).json({ error: "安装包不存在" });
    return;
  }
  res.download(filePath, safeName);
});

app.post("/api/releases/android", requireAdminToken, upload.single("apk"), async (req, res, next) => {
  const uploadedFile = req.file;
  try {
    if (!uploadedFile) {
      res.status(400).json({ error: "请选择 APK 文件" });
      return;
    }

    const versionName = String(req.body.versionName || "").trim();
    const versionCode = Number(req.body.versionCode || 0);
    const releaseNotes = String(req.body.releaseNotes || "").trim();
    const force = req.body.force === "true" || req.body.force === true;

    if (!versionName || !Number.isInteger(versionCode) || versionCode <= 0) {
      res.status(400).json({ error: "请填写正确的版本名称和版本号" });
      return;
    }

    const currentManifest = readManifest();
    if (currentManifest && versionCode <= currentManifest.versionCode) {
      res.status(409).json({
        error: `版本号必须大于当前已发布的 ${currentManifest.versionCode}`,
      });
      return;
    }

    const sha256 = await checksum(uploadedFile.path);
    const fileName = `aeropass-${sanitize(versionName)}-${versionCode}.apk`;
    const targetPath = path.join(releaseDir, fileName);
    fs.renameSync(uploadedFile.path, targetPath);

    const manifest = {
      platform: "android",
      versionName,
      versionCode,
      apkUrl: `${publicBaseUrl}/downloads/${encodeURIComponent(fileName)}`,
      sha256,
      sizeBytes: fs.statSync(targetPath).size,
      releaseNotes,
      force,
      publishedAt: new Date().toISOString(),
    };

    const pendingManifestPath = `${manifestPath}.pending`;
    fs.writeFileSync(pendingManifestPath, JSON.stringify(manifest, null, 2));
    fs.renameSync(pendingManifestPath, manifestPath);
    res.json({ ok: true, manifest });
  } catch (error) {
    next(error);
  } finally {
    if (uploadedFile && fs.existsSync(uploadedFile.path)) {
      fs.rmSync(uploadedFile.path, { force: true });
    }
  }
});

app.use((error, _req, res, _next) => {
  res.status(500).json({ error: error.message || "服务器内部错误" });
});

app.listen(port, "0.0.0.0", () => {
  console.log(`aeroPass update server listening on ${port}`);
});

function requireAdminToken(req, res, next) {
  const header = req.get("Authorization") || "";
  const bearer = header.startsWith("Bearer ") ? header.slice(7) : "";
  const token = bearer || req.get("X-Admin-Token") || req.query.token;
  const supplied = Buffer.from(String(token || ""));
  const expected = Buffer.from(adminToken);
  if (supplied.length !== expected.length || !crypto.timingSafeEqual(supplied, expected)) {
    res.status(401).json({ error: "管理口令不正确" });
    return;
  }
  next();
}

function checksum(filePath) {
  return new Promise((resolve, reject) => {
    const hash = crypto.createHash("sha256");
    const stream = fs.createReadStream(filePath);
    stream.on("data", (chunk) => hash.update(chunk));
    stream.on("error", reject);
    stream.on("end", () => resolve(hash.digest("hex")));
  });
}

function readManifest() {
  if (!fs.existsSync(manifestPath)) {
    return null;
  }
  return JSON.parse(fs.readFileSync(manifestPath, "utf8"));
}

function sanitize(value) {
  return value.replace(/[^0-9A-Za-z._-]/g, "_");
}
