// proxy/dev-proxy.js
const express = require("express");
const { createProxyMiddleware } = require("http-proxy-middleware");

const app = express();

// CORS cho mọi request + xử lý preflight
app.use((req, res, next) => {
  res.header("Access-Control-Allow-Origin", req.headers.origin || "*");
  res.header("Access-Control-Allow-Credentials", "true");
  res.header(
    "Access-Control-Allow-Headers",
    req.headers["access-control-request-headers"] ||
      "Origin, X-Requested-With, Content-Type, Accept, Authorization"
  );
  res.header(
    "Access-Control-Allow-Methods",
    "GET,POST,PUT,PATCH,DELETE,OPTIONS"
  );
  if (req.method === "OPTIONS") return res.sendStatus(204);
  next();
});

// /dapi -> https://dolphin-api.phenikaax.com/api/**
app.use(
  "/dapi",
  createProxyMiddleware({
    target: "https://dolphin-api.phenikaax.com/api",
    changeOrigin: true,
    pathRewrite: { "^/dapi": "" }, // /dapi/v1 -> /v1
  })
);

// /api -> worker mô phỏng (3002)  (nếu cần dùng)
app.use(
  "/api",
  createProxyMiddleware({
    target: "http://116.118.95.187:3002",
    changeOrigin: true,
  })
);

// /mqtt -> broker WS (8083)        (nếu cần dùng web MQTT)
app.use(
  "/mqtt",
  createProxyMiddleware({
    target: "http://116.118.95.187:8083",
    changeOrigin: true,
    ws: true,
    pathRewrite: { "^/mqtt": "/mqtt" },
  })
);

const PORT = 3005;
app.listen(PORT, () => console.log(`Dev proxy on http://localhost:${PORT}`));
