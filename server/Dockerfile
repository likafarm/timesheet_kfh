# Образ API. Собирать из корня репозитория (нужен packages/domain):
#   docker build -f server/Dockerfile -t kfh-api .
#
# Корневой pubspec.yaml — Flutter-приложение, в образе Flutter нет. Поэтому
# здесь собирается свой маленький workspace, а версии пакетов берутся из
# общего pubspec.lock. packages/local_db нужен только затем, что он
# dev-зависимость сервера (тест сверки схемы): pub разрешает и dev-зависимости,
# в exe он не попадает.

FROM dart:3.12 AS build
WORKDIR /src

RUN printf '%s\n' \
    'name: kfh_server_build' \
    'publish_to: none' \
    'environment:' \
    '  sdk: ">=3.12.0 <4.0.0"' \
    'workspace:' \
    '  - packages/domain' \
    '  - packages/local_db' \
    '  - server' \
    > pubspec.yaml
COPY pubspec.lock ./
COPY packages/domain/pubspec.yaml packages/domain/
COPY packages/local_db/pubspec.yaml packages/local_db/
COPY server/pubspec.yaml server/
RUN dart pub get

COPY packages/domain packages/domain
COPY server server
RUN mkdir -p /out && dart compile exe server/bin/server.dart -o /out/server

# Минимальный образ: только exe, миграции и системные библиотеки из /runtime.
FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /out/server /app/server
COPY server/migrations /app/migrations

WORKDIR /app
ENV PORT=8080 MIGRATIONS_DIR=/app/migrations
EXPOSE 8080
USER 65534:65534
HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
    CMD ["/app/server", "healthcheck"]
ENTRYPOINT ["/app/server"]
