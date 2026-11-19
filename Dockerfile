# EaglercraftX Browser Server — vendored, checksum-pinned, zero-runtime-download image
#
# Stage 1 (build): verify vendored jar checksums, run PaperClip ONCE at build time
#   (the only Mojang vanilla-jar fetch happens here, in the builder, never at boot),
#   run one seed boot to generate plugin configs, then patch update-check fetches OFF.
# Stage 2 (runtime): temurin 17 JRE + the seed directory + cgroup-aware entrypoint.
#
# Legal notice: this image ships server infrastructure only (Paper + EaglerXServer +
# AuthMe + Via*). No Minecraft client code, game assets, or Eaglercraft browser
# client files are included. See NOTICE.md and README.md ("Legal & EULA").

FROM eclipse-temurin:17-jdk-jammy AS build

WORKDIR /build

# 1) Vendored jars, checksum-verified BEFORE anything else runs
COPY jars/ /build/jars/
COPY CHECKSUMS.txt /build/CHECKSUMS.txt
RUN cd /build/jars && sha256sum -c /build/CHECKSUMS.txt --strict \
    && echo "[build] all vendored jar checksums verified"

# 2) Pre-patch Paper 1.12.2 at BUILD time (PaperClip fetches the vanilla 1.12.2 jar
#    from Mojang's official CDN exactly once, here in the builder — never at boot).
#    paperclip-2 writes the patched jar to cache/patched_1.12.2.jar and then LAUNCHES
#    the server (capped by the timeout). The patched jar is what ships at runtime —
#    NOT the clip jar (which would re-download vanilla at every boot).
RUN mkdir -p /build/patchwork && cd /build/patchwork \
    && cp /build/jars/paper-1.12.2-1620.jar . \
    && ( timeout -s KILL 360 java -DPaper.IgnoreJavaVersion=true -Dcom.mojang.eula.agree=true -jar paper-1.12.2-1620.jar || true ) \
    && test -s /build/patchwork/cache/patched_1.12.2.jar \
    && cp /build/patchwork/cache/patched_1.12.2.jar /build/patchwork/paper-1.12.2-patched.jar \
    && echo "[build] patched jar staged:" && ls -la /build/patchwork/paper-1.12.2-patched.jar

# 3) One seed boot at build time: generates eula.txt acceptance state, plugin default
#    configs (EaglercraftXServer, EaglerWeb, AuthMe, Via*), then a clean stop.
#    No world is shipped: worlds are generated on the user's volume at first boot.
COPY server-icon.png /tmp/server-icon.png
RUN mkdir -p /build/seed/plugins && cd /build/seed \
    && cp /build/patchwork/paper-1.12.2-patched.jar ./server.jar \
    && cp /build/jars/EaglerXServer.jar /build/jars/EaglerWeb.jar /build/jars/EaglerXRewind.jar \
          /build/jars/AuthMe-5.6.0-legacy.jar /build/jars/ViaVersion-5.12.2.jar \
          /build/jars/ViaBackwards-5.12.2.jar /build/jars/ViaRewind-4.2.0.jar ./plugins/ \
    && cp /tmp/server-icon.png ./server-icon.png \
    && printf 'eula=true\n' > eula.txt \
    && ( (sleep 75; echo stop) | timeout -s KILL 420 java -Xms256m -Xmx768m \
         -DPaper.IgnoreJavaVersion=true -Dcom.mojang.eula.agree=true -jar server.jar nogui || true ) \
    && echo "[build] seed boot complete" && ls -la /build/seed /build/seed/plugins

# 4) Patch the generated configs: disable every boot-time network fetch
COPY patches/ /build/patches/
RUN bash /build/patches/apply.sh /build/seed \
    && echo "[build] config patches applied"

# ---- runtime ----

FROM eclipse-temurin:17-jre-jammy AS runtime

ENV TZ=Etc/UTC

# Seed directory: pre-patched server.jar + verified plugin jars + generated configs
COPY --from=build /build/seed /opt/seed
COPY eaglerweb-root/index.html /opt/seed/plugins/EaglerWeb/web/index.html

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh && mkdir -p /data

WORKDIR /data
EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
