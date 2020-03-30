FROM alpine:3.5
ADD configure.sh /configure.sh
RUN apk add --no-cache --virtual .build-deps ca-certificates curl 
RUN chmod +x /configure.sh
RUN chmod +x /v2ray
RUN chmod +x /v2ctl
CMD /configure.sh
