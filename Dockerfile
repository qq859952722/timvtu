FROM alpine

COPY wwwroot.tar.gz /wwwroot/wwwroot.tar.gz
COPY entrypoint.sh /entrypoint.sh

RUN set -ex\
    && apk update \
    && apk upgrade \
    && apk add wget unzip qrencode\
    && chmod +x /entrypoint.sh

CMD /entrypoint.sh
