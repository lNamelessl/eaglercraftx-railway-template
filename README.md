A Minecraft server your friends join from a browser tab: Paper 1.12.2 with EaglercraftXServer 1.1.1 baked in as checksum-pinned jars — zero deploy prompts, zero boot-time downloads, a healthcheck-gated deploy, and a real TCP proxy so Java Edition players can join too.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/eaglercraftx-browser-server)

## What this is

- **Browser play, no install.** Players open an Eaglercraft 1.12.2 client from eaglercraft.com and Direct Connect to `wss://your-domain.up.railway.app` — the landing page on your deployment shows the exact address, derived from the page you are already on.
- **The server ships, the client does not.** Server infrastructure only: Paper 1.12.2 (PaperMC build 1620), EaglercraftXServer/EaglerWeb/EaglerXRewind 1.1.1, AuthMe 5.6.0 (the legacy build that runs on 1.12.2), Via*. No Minecraft client code and no game assets included; you bring your own client. See the legal section — read it.
- **Zero prompts, zero variables.** The heap is computed from your plan's memory at boot: half the container limit, 512 MB floor, 4 GB cap, `-Xms256m`, and deliberately **no AlwaysPreTouch** — so the server does not pre-commit two thirds of your RAM at idle (the failure mode that OOM-crashes other Eaglercraft templates on smaller plans).
- **Vendored and checksum-pinned.** Every jar lives in this repo with a SHA256 in CHECKSUMS.txt, verified at image build, and Paper is pre-patched at build time — so **boot-time downloads are zero**: no vanilla-jar fetch, no plugin self-updates, no cert fetches, no GeoIP download.
- **Healthcheck-gated deploys.** The deploy is not marked SUCCESS until the landing page answers 200 on port 8080, so a broken boot is visible immediately instead of crash-looping silently.
- **Java Edition joins too.** A TCP proxy is provisioned automatically for the same port: Java clients (1.8 through latest, via Via*) connect through the proxy host:port in your Variables tab.

## Legal & EULA (read before deploying)

- **Not affiliated with Mojang or Microsoft.** "Minecraft" is a trademark of Mojang Synergies AB.
- **You accept the Minecraft EULA by running the server.** The image bakes `eula=true` (and passes `-Dcom.mojang.eula.agree=true`) so the server starts without an interactive prompt. By deploying you, the operator, accept Mojang's EULA — which restricts commercial use. Use it for a friend group, not as a paid product.
- **DMCA context, disclosed.** On 2026-10-14 Mojang filed a GitHub takedown (notice: github/dmca, 2026-10-14-minecraft.md) covering a network of 111 repositories hosting Eaglercraft **client source code**. This template ships **no client code and no game assets** — only server-side components: Paper (LGPL, PaperMC's official CDN), the EaglerX server plugin (from lax1dude's own repository, release v1.1.1), AuthMe (GPL), Via* (GPL). Enforcement risk is real and ongoing; this template vendors pinned copies in its own repo so it does not depend on any takedown-prone URL at deploy time.
- **Checksums.** Every vendored jar's SHA256 is in CHECKSUMS.txt, re-verified inside the Docker build. Nothing is fetched from the internet at boot.

## After deploying (5 steps)

1. Wait for the deploy to turn SUCCESS — the healthcheck gates it on the landing page (first boot also generates a fresh world, typically under two minutes).
2. Open the deploy log: the banner prints your exact join address, `EAGLERCRAFT JOIN URL: wss://your-domain.up.railway.app`.
3. Open the domain in a browser — the landing page shows the same `wss://` address. Open an Eaglercraft 1.12.2 client from eaglercraft.com, choose Direct Connect, paste the address.
4. In game, type `/register password password` (your password twice). New deploy = fresh world: the first account is yours, pick a strong password.
5. Java Edition players: read the TCP proxy host:port from the Variables tab (`RAILWAY_TCP_PROXY_DOMAIN`, `RAILWAY_TCP_PROXY_PORT`) and connect with any client from 1.8 to latest.

## Credentials checklist

None. Nothing to paste, no tokens, no secrets — the deploy form asks nothing and the service defines no required variables. The only "account" is the in-game one you create with `/register` (AuthMe offline-mode).

## RAM and cost honesty (measured on Railway)

| Container plan | JVM heap (computed) | Idle memory measured | Verdict |
| --- | --- | --- | --- |
| 1 GB | 512 MB (floor) | — | Not supported: boot may OOM during world generation |
| 2 GB | 1 GB | 0.60 GB (local container run) | Works: solo/friend-group server, vanilla gameplay |
| 4 GB | 2 GB | not measured (est. 0.8-1.1 GB) | Comfortable: small groups, modest plugin load |
| 8 GB | ~3.8 GB (half of cap, under the 4 GB ceiling) | 0.79 GB cgroup, 0.68 GB java RSS (measured on Railway) | Headroom for redstone-heavy worlds |

Always-on economics: a Minecraft server is long-lived and memory-hungry — on Railway it costs more per month than a cheap VPS. Where Railway wins is **intermittent** friend-group servers: one-click deploy, per-second billing for actual use, free plan resizing, delete when the world dies. The rival template in this niche hard-commits a 5.3 GB heap with AlwaysPreTouch and idles at 6.3 GB — it needs an 8 GB plan before anyone even joins; this one runs on 2 GB.

## Upgrading and tuning

- All state lives on the `/data` volume: world, AuthMe accounts, plugin configs, the landing page (`plugins/EaglerWeb/web/index.html`). Delete the volume = fresh world.
- Plugin configs are pre-seeded with every network fetch disabled (update checker, certs, GeoIP, bStats). Edit them on the volume; they survive redeploys.
- The heap follows your plan automatically. Optional `JAVA_ARGS` variable adds per-boot flags (never `-Xmx`; the computed heap already matches your plan).

# Deploy and Host

## About Hosting

One service, one volume at /data, one public HTTP domain (browser + WebSocket) and one TCP proxy (Java Edition) — both targeting the same internal port 8080, because EaglercraftXServer injects its browser listener into the Paper server channel: one port serves Minecraft protocol, HTTPS landing page, and WebSocket game traffic at once.

The image builds in two stages. Stage one verifies every vendored jar against CHECKSUMS.txt, runs PaperClip once to pre-patch Paper 1.12.2 (the single Mojang CDN fetch happens in the builder, never at boot), and performs one seed boot that generates the plugin configs, then patches every network fetch off: EaglerX update checker off, update-certificate downloads off, GeoIP off, metrics off — and no SkinsRestorer anywhere (it self-updates at boot; that artifact churn is deliberately not reproduced). Stage two is a small temurin 17 JRE with the seed and a cgroup-aware entrypoint.

At boot the entrypoint seeds /data once from the image (marker-guarded — it never re-fires, so world, accounts, and configs persist across redeploys), computes the JVM heap from the container's cgroup memory limit (half the limit, 512 MB floor, 4 GB cap, -Xms256m, no AlwaysPreTouch), prints the join banner, then execs Paper. Worlds are generated on the volume at first boot, not baked into the image.

## Why Deploy

- **It boots on small plans.** The heap is a fraction of your container limit with no pre-touch; measured idle memory is under 1 GB — the dominant Eaglercraft listing in this marketplace commits 5.3 GB of heap at boot and OOM-crashes below 8 GB.
- **It tells you it worked.** Healthcheck-gated deploys, a join-address banner in the logs, and a landing page that derives your wss address from the page itself.
- **No boot-time network dependencies.** All jars vendored, checksum-pinned, pre-patched at build; update checks, certificates, GeoIP, metrics off; no plugin self-updater. A deploy does not break because some upstream repo did.
- **Java and browser clients both join.** The TCP proxy is provisioned by the template config itself — no manual Networking step — and Via* widens Java compatibility to 1.8 through latest.

## Common Use Cases

- A friend-group Minecraft world everyone joins from a browser tab — no Java install, no port-forwarding, one link.
- A short-lived event server: deploy, play, delete — per-second billing suits a world that only exists for a weekend.
- A mixed-client server: Eaglercraft browser players plus Java Edition friends joining through the TCP proxy.
- A safe offline-mode sandbox with account registration (AuthMe) so only people you gave the address to can play.

## Dependencies for

### Deployment Dependencies

- [Paper 1.12.2 build 1620](https://fill.papermc.io/v3/projects/paper) — the server runtime (LGPL; vendored, SHA256-pinned)
- [EaglercraftXServer v1.1.1](https://github.com/lax1dude/eaglerxserver) — browser-protocol translation layer, EaglerWeb landing-page host, EaglerXRewind 1.5-client support (vendored, SHA256-pinned)
- [AuthMe 5.6.0](https://github.com/AuthMe/AuthMeReloaded) — offline-mode account registration (GPL; vendored, SHA256-pinned)
- [ViaVersion 5.12.2 / ViaBackwards 5.12.2 / ViaRewind 4.2.0](https://modrinth.com/user/via) — Java client version range widening (GPL; vendored, SHA256-pinned)
- One Railway volume (world, accounts, configs) and one TCP proxy on port 8080, both provisioned automatically from the template config
- Players need their own Eaglercraft 1.12.2 browser client — from eaglercraft.com (this template ships none)

## Honest positioning

A listing named Eaglercraft (by railbi) already serves this niche and fails at 0 percent health across 51 deploys: a 5.3 GB heap with AlwaysPreTouch, no healthcheck, no TCP proxy, and boot-time downloads from three third-party URLs (its own upstream repo is gone, so nothing can be forked). This template is the deliberate fix: measured memory behavior, a gated deploy, automatic Java join, vendored pins, and the legal posture written out instead of buried. The client ecosystem remains DMCA-gray and enforcement is active — read the legal section and decide for yourself.
