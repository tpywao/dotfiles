FROM debian:stable AS builder

RUN apt -yqq update & apt -yqq install ffmpeg

FROM debian:stable-slim AS runner

COPY --from=builder /usr/local/bin/ffmpeg /usr/local/bin/ffmpeg
COPY --from=builder /usr/local/bin/ffprobe /usr/local/bin/ffprobe
COPY --from=builder /usr/local/bin/ffplay /usr/local/bin/ffplay
COPY --from=builder /usr/local/bin/ffmpeg-normalize /usr/local/bin/ffmpeg-normalize

ENTRYPOINT  ["ffmpeg"]
CMD         ["--help"]
