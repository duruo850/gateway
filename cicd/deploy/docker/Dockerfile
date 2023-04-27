FROM openresty/openresty:1.21.4.1-6-bionic


ADD nginx /usr/local/bin/nginx/
ADD consul_template /usr/local/bin/consul_template/
ADD lua/auth /usr/local/openresty/lualib/auth
ADD lua/http /usr/local/openresty/lualib/resty
ADD supervisor/supervisord.conf /etc/
ADD cicd/deploy/docker/run /usr/local/bin/


ENV TZ=Asia/Shanghai

# alpine' cp、mv is a versiob of busybox，different from ubuntu, so install coreutils
RUN cd /usr/bin \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y tzdata && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        cron \
        vim \
        supervisor \
        curl \
    && curl -fSL https://releases.hashicorp.com/consul-template/${CONSUL_TEMPLATE_VERSION}/consul-template_${CONSUL_TEMPLATE_VERSION}_linux_amd64.zip -o consul-template.zip \
    && unzip consul-template.zip \
    && rm -rf consul-template.zip \
    && chmod +x consul-template \
    && chmod +x /usr/local/bin/run \
    && chmod +x /usr/local/bin/consul_template/consul_handler \
    && chmod +x /usr/local/bin/nginx/conf_wapper

EXPOSE 80

WORKDIR /usr/local/openresty/

VOLUME ["/usr/local/openresty/nginx/cert/primary.pem", "/usr/local/openresty/nginx/cert/key.pem"]

CMD [ "/usr/local/bin/run" ]

