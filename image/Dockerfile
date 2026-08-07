FROM debian:trixie

LABEL description="Firefox ESR isolated by e_f & Grok"

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8 \
    MOZ_DISABLE_CONTENT_SANDBOX=1 \
    HOME=/home/firefox

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        locales \
        fonts-liberation \
        fonts-noto-core \
        fonts-noto-color-emoji \
        libgtk-3-0 \
        libxt6 \
        libx11-xcb1 \
        libasound2t64 \
        libpulse0 \
        firefox-esr \
    && sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
    && locale-gen en_US.UTF-8 \
    && update-locale LANG=en_US.UTF-8 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/*

ARG USER_ID=1000
ARG GROUP_ID=1000

RUN groupadd -g ${GROUP_ID} firefox \
    && useradd -m -u ${USER_ID} -g ${GROUP_ID} -s /bin/bash firefox \
    && mkdir -p /home/firefox/.mozilla \
                /home/firefox/Downloads \
    && chown -R firefox:firefox /home/firefox

USER firefox
WORKDIR /home/firefox

CMD ["firefox-esr", "--no-remote"]
