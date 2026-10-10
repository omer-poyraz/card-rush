# Card Rush signaling server (Cloudflare Worker)

Relays only WebRTC connection setup between a room host and guests, and can hand out
short-lived TURN credentials. Game and voice data go device-to-device over WebRTC.

## Cost and limits (checked 2026-10)
- Workers Free: 100,000 requests/day; on Durable Objects every WebSocket message counts
  as a request. One room setup ≈ 20–60 messages, so roughly 2,000+ room joins/day fit.
  Over the limit requests fail (no surprise bill on the free plan).
- Durable Objects on the free plan must be SQLite-backed (configured in `wrangler.toml`).
  Hibernating rooms are not billed for duration.
- **TURN is separate**: Cloudflare Realtime TURN has a free tier of 1,000 GB/month, then
  $0.05/GB egress (paid account needed beyond the free tier). TURN is only used when two
  devices can't connect directly (common on mobile carrier NAT). Card Rush game traffic is
  tiny (KB per match); voice is ~64 kbit/s per active speaker per listener.
Re-check current prices before release — free tiers can change.

## Deploy
```bash
cd server/signaling-worker
npx wrangler login
npx wrangler deploy                  # prints https://card-rush-signaling.<account>.workers.dev
# optional TURN relay (create a TURN key in the Cloudflare dashboard → Realtime → TURN):
npx wrangler secret put TURN_KEY_ID
npx wrangler secret put TURN_KEY_API_TOKEN
```
Then set the URL (not a secret) in `project.godot`:
```
[card_rush]
online/signaling_url="wss://card-rush-signaling.<account>.workers.dev/ws"
```
Without TURN, players behind strict NATs may fail to connect; the game then shows a clear
error and LAN / direct IP remain available.

## Local development
`godot --headless --path . res://tools/signaling_server.tscn -- --port 9080` runs the
GDScript dev server with the same protocol (`ws://127.0.0.1:9080`).
