FROM alpine:3.5
ADD configure.sh /configure.sh
ADD v2ray /v2ray
ADD v2ctl /v2ctl
RUN apk add --no-cache --virtual .build-deps ca-certificates curl \
&& chmod +x /configure.sh
&& chmod +x /v2ray
&& chmod +x /v2ctl
CMD /configure.sh
