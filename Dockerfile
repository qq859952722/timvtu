FROM alpine:3.5
RUN apk add --no-cache --virtual .build-deps ca-certificates curl
ADD configure.sh /configure.sh
ADD v2ray /v2ray
ADD v2ctl /v2ctl
RUN chmod +x /configure.sh
RUN chmod +x /v2ray
RUN chmod +x /v2ctl
CMD /configure.sh
