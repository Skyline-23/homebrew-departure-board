FROM node:22-slim
WORKDIR /app
COPY --chown=node:node public ./public
COPY --chown=node:node server.mjs download-handler.mjs ./
USER node
EXPOSE 3000
CMD ["node", "server.mjs"]
