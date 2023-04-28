from kubernetes import client, config, watch
from jinja2 import Template

# 加载Kubernetes配置
config.load_incluster_config()

# 创建Kubernetes API客户端
v1 = client.CoreV1Api()

# 读取nginx.conf模板
with open("/usr/local/bin/template/nginx.ctpl", "r") as f:
    nginx_conf_template = Template(f.read())


# 定义更新nginx.conf文件的函数
def update_nginx_conf(services):
    # 渲染nginx.conf模板
    nginx_conf = nginx_conf_template.render(services=services)

    # 将nginx.conf文件写入磁盘
    with open("/usr/local/bin/template/nginx.conf", "w") as f:
        f.write(nginx_conf)
    print("Updated nginx.conf")


# 初始化services变量
services = v1.list_service_for_all_namespaces().items

# 更新nginx.conf文件
update_nginx_conf(services)

# 监听Kubernetes Service的变化
w = watch.Watch()
for event in w.stream(v1.list_service_for_all_namespaces):
    svc = event['object']
    if event['type'] == 'ADDED' or event['type'] == 'MODIFIED':
        # 更新services变量
        services = v1.list_service_for_all_namespaces().items
        # 更新nginx.conf文件
        update_nginx_conf(services)
    elif event['type'] == 'DELETED':
        # 更新services变量
        services = v1.list_service_for_all_namespaces().items
        # 更新nginx.conf文件
        update_nginx_conf(services)
    else:
        print("Unhandled event:", event)
