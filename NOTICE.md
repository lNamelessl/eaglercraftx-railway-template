# NOTICE — third-party components vendored in this repository

This repository ships server infrastructure only. No Minecraft client code, no game
assets, and no Eaglercraft browser client files are included anywhere in this repo.

| Component | Version | Source (pinned) | License | Notes |
| --- | --- | --- | --- | --- |
| Paper (pre-patched server jar) | 1.12.2 build 1620 | PaperMC official distribution (fill.papermc.io) | LGPL-3.0 | Pre-patched at image build with PaperClip; SHA256 in CHECKSUMS.txt |
| EaglerXServer | 1.1.1 | github.com/lax1dude/eaglerxserver, release v1.1.1 | License per upstream repo (LGPL-style notice in repo LICENSE) | Browser-protocol translation layer (Bukkit plugin mode) |
| EaglerWeb | 1.1.1 | github.com/lax1dude/eaglerxserver, release v1.1.1 | same as EaglerXServer | In-server HTTP file host (serves the landing page) |
| EaglerXRewind | 1.1.1 | github.com/lax1dude/eaglerxserver, release v1.1.1 | same as EaglerXServer | Eaglercraft 1.5.2 client protocol translation |
| AuthMe (legacy build) | 5.6.0 | github.com/AuthMe/AuthMeReloaded, release 5.6.0 | GPL-3.0 | Offline-mode account registration (the legacy build is the one compatible with Paper 1.12.2 — the 6.x line aborts on it) |
| ViaVersion | 5.12.2 | Modrinth via project (cdn.modrinth.com) | GPL-3.0 | Java clients newer than 1.12.2 join the server |
| ViaBackwards | 5.12.2 | Modrinth via project (cdn.modrinth.com) | GPL-3.0 | Java clients older than 1.12.2 join the server |
| ViaRewind | 4.2.0 | Modrinth via project (cdn.modrinth.com) | GPL-3.0 | Pre-1.8 Java client support |

The Docker build verifies every jar against CHECKSUMS.txt (SHA256) before use and
performs the one-time PaperClip patch inside the builder. Nothing is downloaded from
the internet at server boot.

Trademarks: Minecraft is a trademark of Mojang Synergies AB. This template is not
affiliated with, endorsed by, or connected to Mojang, Microsoft, or the Eaglercraft
project in any way. Running the server constitutes acceptance of the Minecraft EULA
by the operator (non-commercial usage per the EULA). The Eaglercraft client ecosystem
is subject to active DMCA enforcement (GitHub notice 2026-10-14 covering client-source
repositories); this template intentionally ships no client code and depends on no
external URLs at deploy time.
