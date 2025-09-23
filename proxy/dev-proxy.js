// dev-proxy.js
const { createProxyMiddleware } = require("http-proxy-middleware");

module.exports = function (app) {
  // Worker simulator
  app.use(
    "/api",
    createProxyMiddleware({
      target: "http://116.118.95.187:3002",
      changeOrigin: true,
      onProxyReq: (proxyReq) => proxyReq.removeHeader("Origin"),
    })
  );

  // Dolphin API backend
  app.use(
    "/dapi",
    createProxyMiddleware({
      target: "http://116.118.95.187:3000",
      changeOrigin: true,
      secure: false,
      pathRewrite: { "^/dapi": "/api" },
    })
  );

  // MQTT WebSocket
  app.use(
    "/mqtt",
    createProxyMiddleware({
      target: "ws://116.118.95.187:8083",
      changeOrigin: true,
      ws: true,
      pathRewrite: { "^/mqtt": "/mqtt" },
    })
  );

  // OSRM
  app.use(
    "/osrm",
    createProxyMiddleware({
      target: "https://router.project-osrm.org",
      changeOrigin: true,
      secure: true,
      pathRewrite: { "^/osrm": "" },
    })
  );
};
