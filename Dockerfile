FROM tobix/wine:staging

RUN apt-get update -qq && apt-get install -y -qq \
    xvfb wget cabextract procps \
    libegl-dev libgl1-mesa-dri libgbm1 libdrm2 \
    libxcomposite1 libxdamage1 libxrandr2 \
    libasound2t64 libpulse0 libpango-1.0-0 libcairo2 libatspi2.0-0t64 \
    libfontconfig1 libfreetype6 libx11-xcb1 libxcb1 libxfixes3 \
    libxkbcommon0 libxkbfile1 \
    && rm -rf /var/lib/apt/lists/*

RUN wget -q https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks \
    -O /usr/local/bin/winetricks && chmod +x /usr/local/bin/winetricks

COPY launch.sh /launch.sh
RUN chmod +x /launch.sh

ENTRYPOINT ["/launch.sh"]
