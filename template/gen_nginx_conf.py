from kubernetes import client, config, watch
from jinja2 import Template


class NginxConfGenerator:

    def __init__(self, nginx_ctpl_path, nginx_conf_path):
        # 加载Kubernetes配置
        config.load_incluster_config()

        # 创建Kubernetes API客户端
        self.k8s_client = client.CoreV1Api()

        self.namespace = "default"
        self._nginx_ctpl_template = self.read_ctpl(nginx_ctpl_path)
        self._nginx_conf_path = nginx_conf_path

        # 第一版生成
        self.update_nginx_conf()

    @staticmethod
    def read_ctpl(ctpl_path) -> Template:
        """
        读取nginx.conf模板
        :return:
        """
        with open(ctpl_path, "r") as f:
            return Template(f.read())

    def update_nginx_conf(self):
        """
        定义更新nginx.conf文件的函数
        :return:
        """
        # 渲染nginx.conf模板
        nginx_conf = self._nginx_ctpl_template.render(services=self.current_services())

        # 将nginx.conf文件写入磁盘
        with open(self._nginx_conf_path, "w") as f:
            f.write(nginx_conf)
        print("Updated nginx.conf")

    def current_services(self):
        return self.k8s_client.list_namespaced_service(self.namespace).items

    def watch(self):
        # 监听Kubernetes Service的变化
        w = watch.Watch()
        for event in w.stream(self.k8s_client.list_namespaced_service, self.namespace):
            if event['type'] in ('ADDED', 'MODIFIED', 'DELETED'):
                self.update_nginx_conf()
            else:
                print("Unhandled event:", event)


if __name__ == "__main__":
    NginxConfGenerator("nginx.ctpl", "nginx.conf").watch()
