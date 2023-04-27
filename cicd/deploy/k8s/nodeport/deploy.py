#!/usr/bin/python3
# coding=utf-8
"""
Created on 2018-1-10
docker 部署脚本
@author: Jay
"""
import os;
import site;
import subprocess;

cur_path = os.path.dirname(os.path.realpath(__file__));
workspace = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(cur_path)))));
site.addsitedir(workspace);
site.addsitedir("/var/app/mage-utils/workspace/utils");
site.addsitedir(workspace);
site.addsitedir("/var/app/mage-utils/workspace/interfaces");
from utils import logger
from utils.linux.deploy import IK8SDeploy

logger.init_log(os.path.basename(workspace))

service_type = "gateway"
version = "3.0.0"


def do_cmd(cmd):
    """
    执行命令
    :param cmd:
    :return:
    """
    print("do_cmd start cmd:=========%s========" % cmd)
    stdout, stderr = subprocess.Popen(
        cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, close_fds=True,
        executable='/bin/bash').communicate()
    print("do_cmd end cmd:%s, stdout:%s stderr:%s" % (cmd, stdout, stderr))


class K8sDeploy(IK8SDeploy):
    def build(self):
        """
        构建镜像
        :return:
        """
        print("build on:", workspace, "version:", version)
        os.chdir(workspace)

        image_name = "%s:%s" % (self.service_type, self.version)
        cmd = " docker build -t {image_name} -f {docker_file} .".format(
            image_name=image_name, docker_file=self.docker_file)
        do_cmd(cmd)


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument('command', type=str, help="support this command: %s" % IK8SDeploy.commands())
    parser.add_argument('service', type=str, help="please set service.yaml!")
    args = parser.parse_args()
    print("args,", args)

    DEPLOY_PATH = os.path.dirname(os.path.dirname(cur_path))
    DOCKER_DEPLOY_PATH = os.path.join(DEPLOY_PATH, "docker")
    K8S_DEPLOY_PATH = os.path.join(DEPLOY_PATH, "k8s")

    obj = K8sDeploy(
        workspace,
        service_type,
        version,
        port=None,
        docker_file=os.path.join(DOCKER_DEPLOY_PATH, "Dockerfile"),
        k8s_deployment_file=os.path.join(cur_path, "Deployment.yaml"),
        k8s_service_file=os.path.join(cur_path, args.service),
        can_update_deployment_file=False,
    )
    if hasattr(obj, args.command):
        getattr(obj, args.command)()
    else:
        print(parser.format_usage())
        exit(1)
