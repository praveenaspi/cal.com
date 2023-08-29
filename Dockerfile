FROM node:18 as builder

WORKDIR /usr/src/app

ARG NEXT_PUBLIC_LICENSE_CONSENT
ARG CALCOM_TELEMETRY_DISABLED
ARG DATABASE_URL
ARG NEXTAUTH_SECRET=secret
ARG CALENDSO_ENCRYPTION_KEY=secret
ARG MAX_OLD_SPACE_SIZE=4096

ENV NEXT_PUBLIC_WEBAPP_URL=http://NEXT_PUBLIC_WEBAPP_URL_PLACEHOLDER \
    NEXT_PUBLIC_LICENSE_CONSENT=$NEXT_PUBLIC_LICENSE_CONSENT \
    CALCOM_TELEMETRY_DISABLED=$CALCOM_TELEMETRY_DISABLED \
    DATABASE_URL=$DATABASE_URL \
    NEXTAUTH_SECRET=${NEXTAUTH_SECRET} \
    CALENDSO_ENCRYPTION_KEY=${CALENDSO_ENCRYPTION_KEY} \
    NODE_OPTIONS=--max-old-space-size=${MAX_OLD_SPACE_SIZE}

COPY ["package.json","yarn.lock",".env",".yarnrc.yml","playwright.config.ts","turbo.json","git-init.sh","git-setup.sh", "./"]
COPY [".env", ".env"]
COPY [".yarn","./.yarn"]
COPY ["apps","./apps"]
COPY ["packages","./packages"]

RUN yarn config set httpTimeout 1200000
RUN npx turbo prune --scope=@calcom/web --docker
RUN yarn install
# RUN yarn db-deploy
# RUN yarn --cwd /usr/src/app/packages/prisma seed-app-store

# RUN yarn config set httpTimeout 1200000 && \ 
#     npx turbo prune --scope=@calcom/web --docker && \
#     yarn install && \
#     yarn db-deploy && \
#     yarn --cwd packages/prisma seed-app-store

RUN yarn turbo run build --filter=@calcom/web

# RUN yarn plugin import workspace-tools && \
#     yarn workspaces focus --all --production
RUN rm -rf node_modules/.cache .yarn/cache apps/web/.next/cache

FROM node:18 as builder-two

WORKDIR /usr/src/app
ARG NEXT_PUBLIC_WEBAPP_URL=http://localhost:3000

ENV NODE_ENV production

COPY /package.json /.yarnrc.yml /yarn.lock /turbo.json ./
COPY .yarn ./.yarn
COPY --from=builder /usr/src/app/node_modules ./node_modules
COPY --from=builder /usr/src/app/packages ./packages
COPY --from=builder /usr/src/app/apps/web ./apps/web
COPY --from=builder /usr/src/app/packages/prisma/schema.prisma ./prisma/schema.prisma
COPY docker-scripts docker-scripts

# Save value used during this build stage. If NEXT_PUBLIC_WEBAPP_URL and BUILT_NEXT_PUBLIC_WEBAPP_URL differ at
# run-time, then start.sh will find/replace static values again.
ENV NEXT_PUBLIC_WEBAPP_URL=$NEXT_PUBLIC_WEBAPP_URL
ENV BUILT_NEXT_PUBLIC_WEBAPP_URL=$NEXT_PUBLIC_WEBAPP_URL

# Grant executable permissions to the script file
RUN chmod +x /usr/src/app/docker-scripts/replace-placeholder.sh

RUN /usr/src/app/docker-scripts/replace-placeholder.sh http://NEXT_PUBLIC_WEBAPP_URL_PLACEHOLDER ${NEXT_PUBLIC_WEBAPP_URL}

FROM node:18 as runner

WORKDIR /usr/src/app

COPY --from=builder-two /usr/src/app ./

ARG NEXT_PUBLIC_WEBAPP_URL=http://localhost:3000
ENV NEXT_PUBLIC_WEBAPP_URL=$NEXT_PUBLIC_WEBAPP_URL
ENV BUILT_NEXT_PUBLIC_WEBAPP_URL=$NEXT_PUBLIC_WEBAPP_URL

ENV NODE_ENV production
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=30s --retries=5 \
    CMD wget --spider http://localhost:3000 || exit 1

CMD ["/usr/src/app/docker-scripts/start.sh"]