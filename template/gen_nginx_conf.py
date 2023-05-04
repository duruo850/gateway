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
        service_pods = self.current_service_pods()
        # 渲染nginx.conf模板
        nginx_conf = self._nginx_ctpl_template.render(
            services=list(service_pods.keys()), service_pods=service_pods)

        # 将nginx.conf文件写入磁盘
        with open(self._nginx_conf_path, "w") as f:
            f.write(nginx_conf)
        print("Updated nginx.conf")

    def current_services(self):
        return self.k8s_client.list_namespaced_service(self.namespace).items

    def current_pods(self) -> list:
        return self.k8s_client.list_namespaced_pod(self.namespace).items

    def current_service_pods(self) -> {str: {}}:
        service_pods = {}
        for pod in self.current_pods():
            service = pod.metadata.labels.get('app', None)
            if service is None:
                continue

            spod = []

            # 输出每个容器的端口信息
            for container in pod.spec.containers:
                if container.name == 'istio-proxy':
                    continue

                # 如果容器不指定端口，则无法获取端口信息
                if container.ports is None:
                    continue

                for port in container.ports:
                    spod.append({"pod_ip": pod.status.pod_ip, "port": port.container_port})

            if len(spod) > 0:
                service_pods.setdefault(service, []).extend(spod)
        return service_pods

    def watch(self):
        # 监听Kubernetes Service的变化
        w = watch.Watch()
        for event in w.stream(self.k8s_client.list_namespaced_service, self.namespace):
            if event['type'] in ('ADDED', 'MODIFIED', 'DELETED'):
                self.update_nginx_conf()
            else:
                print("Unhandled event:", event)


if __name__ == "__main__":
    ncg = NginxConfGenerator("nginx.ctpl", "nginx.conf")
    ncg.watch()
