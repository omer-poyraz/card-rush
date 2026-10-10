// Card Rush signaling server (Cloudflare Worker + Durable Object per room).
// It only relays WebRTC setup messages between a room host and its guests and
// optionally hands out short-lived TURN credentials. It never sees room codes
// (only a hash), card data or voice. Protocol: scripts/networking/signaling_client.gd

const MAX_GUESTS = 12;
const MAX_MSG = 16 * 1024;
const MAX_MSGS_PER_MIN = 600;
const KEY_RE = /^[0-9a-f]{16}$/;

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname === "/health") return new Response("ok");
    if (url.pathname !== "/ws") return new Response("Card Rush signaling", { status: 404 });
    if (request.headers.get("Upgrade") !== "websocket") return new Response("expected websocket", { status: 426 });
    const room = url.searchParams.get("room") || "";
    if (!KEY_RE.test(room)) return new Response("bad room", { status: 400 });
    const stub = env.ROOMS.get(env.ROOMS.idFromName(room));
    return stub.fetch(request);
  },
};

export class Room {
  constructor(state, env) {
    this.state = state;
    this.env = env;
  }

  async fetch(request) {
    const room = new URL(request.url).searchParams.get("room");
    const pair = new WebSocketPair();
    // Hibernation API: idle rooms cost no duration.
    this.state.acceptWebSocket(pair[1]);
    pair[1].serializeAttachment({ room, role: "", id: -1, count: 0, windowStart: Date.now() });
    return new Response(null, { status: 101, webSocket: pair[0] });
  }

  sockets() {
    return this.state.getWebSockets().map((ws) => ({ ws, a: ws.deserializeAttachment() || {} }));
  }

  send(ws, msg) {
    try { ws.send(JSON.stringify(msg)); } catch (_) { /* closed */ }
  }

  async webSocketMessage(ws, data) {
    const a = ws.deserializeAttachment() || {};
    // simple per-socket rate limit
    const now = Date.now();
    if (now - a.windowStart > 60000) { a.windowStart = now; a.count = 0; }
    a.count++;
    if (a.count > MAX_MSGS_PER_MIN || typeof data !== "string" || data.length > MAX_MSG) {
      ws.close(1008, "limit");
      return;
    }
    ws.serializeAttachment(a);
    let m;
    try { m = JSON.parse(data); } catch (_) { return; }
    if (!m || typeof m !== "object") return;
    const all = this.sockets();
    switch (m.t) {
      case "join": {
        if (a.role || m.room !== a.room || (m.role !== "host" && m.role !== "guest")) {
          this.send(ws, { t: "error", reason: "bad_request" });
          return;
        }
        const host = all.find((s) => s.a.role === "host");
        if (m.role === "host") {
          if (host) { this.send(ws, { t: "error", reason: "room_taken" }); return; }
          a.role = "host"; a.id = 1;
          ws.serializeAttachment(a);
          await this.state.storage.put("next", 2);
          this.send(ws, { t: "joined", id: 1 });
        } else {
          if (!host) { this.send(ws, { t: "error", reason: "no_room" }); return; }
          if (all.filter((s) => s.a.role === "guest").length >= MAX_GUESTS) { this.send(ws, { t: "error", reason: "full" }); return; }
          const id = (await this.state.storage.get("next")) || 2;
          await this.state.storage.put("next", id + 1);
          a.role = "guest"; a.id = id;
          ws.serializeAttachment(a);
          this.send(ws, { t: "joined", id });
          this.send(host.ws, { t: "peer", id });
        }
        return;
      }
      case "sig": {
        if (!a.role) return;
        const to = Number(m.to);
        const target = all.find((s) => s.a.id === to && (to === 1 || a.role === "host"));
        if (target) this.send(target.ws, { t: "sig", from: a.id, data: m.data || {} });
        return;
      }
      case "ice": {
        this.send(ws, { t: "ice", servers: await this.iceServers() });
        return;
      }
    }
  }

  async iceServers() {
    const id = this.env.TURN_KEY_ID, token = this.env.TURN_KEY_API_TOKEN;
    if (!id || !token) return [];
    try {
      const r = await fetch(`https://rtc.live.cloudflare.com/v1/turn/keys/${id}/credentials/generate-ice-servers`, {
        method: "POST",
        headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
        body: JSON.stringify({ ttl: 4 * 3600 }),
      });
      if (!r.ok) return [];
      const j = await r.json();
      const list = Array.isArray(j.iceServers) ? j.iceServers : [j.iceServers];
      // drop port-53 URLs (blocked on many networks, only cause timeouts)
      return list.map((s) => ({ ...s, urls: [].concat(s.urls).filter((u) => !/:53(\?|$)/.test(u)) }));
    } catch (_) {
      return [];
    }
  }

  async webSocketClose(ws) { this.leave(ws); }
  async webSocketError(ws) { this.leave(ws); }

  leave(ws) {
    const a = ws.deserializeAttachment() || {};
    const others = this.sockets().filter((s) => s.ws !== ws);
    if (a.role === "host") {
      for (const s of others) { this.send(s.ws, { t: "host_left" }); try { s.ws.close(1000, "host_left"); } catch (_) {} }
      this.state.storage.deleteAll();
    } else if (a.role === "guest") {
      const host = others.find((s) => s.a.role === "host");
      if (host) this.send(host.ws, { t: "peer_left", id: a.id });
    }
  }
}
