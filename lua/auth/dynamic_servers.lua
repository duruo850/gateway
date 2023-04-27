local k8s_dynamic_servers={}


function k8s_dynamic_servers:dump2file()
    local dynamic_servers = require "resty.dynamic_servers"
    local template = require "resty.template"

    -- 从 Kubernetes API 中获取服务信息
    local services, err = dynamic_servers.get_services("default")
    if not services then
        ngx.log(ngx.ERR, "Failed to get services: ", err)
    end

    local mtime = ngx.parse_http_time(ngx.var.upstream_http_last_modified or "")
    if mtime > last_modified then
        ngx.log(ngx.INFO, "Updating template")

        -- 生成 Nginx 配置文件
        local tpl = template.compile("/usr/local/bin/template/nginx.ctpl")
        local conf = tpl({ services = services })

        -- 写入 Nginx 配置文件
        local file = io.open("/usr/local/openresty/nginx/conf/nginx.conf", "w")
        file:write(conf)
        file:close()
    end

end


return k8s_dynamic_servers