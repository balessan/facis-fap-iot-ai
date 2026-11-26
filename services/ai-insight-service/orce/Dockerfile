FROM ecofacis/xfsc-orce:2.0.3

USER root

# Fix node-gyp compatibility with Node 20.19: the base image's npm bundles a
# node-gyp with a broken logger. Pinned, not npm@latest: npm 12 needs Node 22,
# and the base image runs Node 20. npm 11.21.2 supports Node ^20.17 || >=22.9
# and bundles node-gyp 12.
RUN npm install -g npm@11.21.2

# ── Bundle exported flows for runtime bootstrap ──────────────────────
COPY flows /opt/ai-insight-flows

# ── Optional runtime bundle (.env + certs) for image-ready runs ─────
COPY runtime /opt/ai-insight-runtime

# ── Custom entrypoint ────────────────────────────────────────────────
COPY entrypoint.sh /usr/local/bin/entrypoint-ai-insight-orce.sh
RUN chmod +x /usr/local/bin/entrypoint-ai-insight-orce.sh

ENTRYPOINT ["/usr/local/bin/entrypoint-ai-insight-orce.sh"]

# Do NOT switch user here; the original ORCE entrypoint handles it.
