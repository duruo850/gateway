FROM openresty/openresty:1.21.4.1-6-bionic


ADD nginx /usr/local/bin/nginx/
ADD lua/auth /usr/local/openresty/lualib/auth
ADD lua/http /usr/local/openresty/lualib/resty
ADD supervisor/supervisord.conf /etc/
ADD cicd/deploy/docker/run /usr/local/bin/
ADD template /usr/local/bin/template/


ENV TZ=Asia/Shanghai
ENV LUAROCKS_VERSION 3.9.2
ENV KUBERNETES_VERSION 26.1.0
ENV JINJA2_VERSION 3.0.3

# alpine' cp、mv is a versiob of busybox，different from ubuntu, so install coreutils
RUN cd /usr/bin \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y tzdata && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y cron vim supervisor curl python3-pip \
    && pip3 install kubernetes==${KUBERNETES_VERSION} && pip3 install jinja2==${JINJA2_VERSION} \
    && chmod +x /usr/local/bin/run \
    && chmod +x /usr/local/bin/nginx/conf_wapper

EXPOSE 80

WORKDIR /usr/local/openresty/

VOLUME ["/usr/local/openresty/nginx/cert/primary.pem", "/usr/local/openresty/nginx/cert/key.pem"]

CMD [ "/usr/local/bin/run" ]

