FROM bitwalker/alpine-elixir:1.9.0 as builder
ADD . /app
WORKDIR /app
ENV MIX_ENV=prod
RUN mix do deps.get, deps.compile, release

FROM alpine:3.10
RUN apk add --no-cache \
      ca-certificates \
      openssl-dev \
      ncurses-dev \
      unixodbc-dev \
      zlib-dev

WORKDIR /app
COPY --from=builder /app/_build/prod/rel/assistant .
CMD ["bin/assistant", "start"]
