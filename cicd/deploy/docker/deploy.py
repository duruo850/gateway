#!/usr/bin/python3
# coding=utf-8
"""
Created on 2018-11-27
@author: Jay
"""
import os;

cur_path = os.path.dirname(os.path.realpath(__file__));
workspace = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(cur_path))))
import os
import argparse
import subprocess

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


class IService:
    def __init__(self, args):
        """

        :param args: 启动参数
        """
        self.args = args

    def build(self):
        """
        构建镜像
        :return:
        """
        assert self.args.docker_file
        print("build on:", workspace, "version:", version)
        os.chdir(workspace)
        do_cmd("""docker build -t gateway:{version} --no-cache -f {docker_file} . """.format(
            version=version, docker_file=self.args.docker_file))

    def stop(self):
        """
        结束服务
        :return:
        """
        print("stop")
        cmd = """docker ps | grep {service_type} """.format(service_type=self.args.service_type)
        cmd += """| awk '{print $1}' | xargs docker stop"""
        do_cmd(cmd)

        print("rm")
        cmd = """docker container rm {service_type} """.format(service_type=self.args.service_type)
        do_cmd(cmd)

    def clear(self):
        """
        清空服务
        :return:
        """
        print("clear")
        print("container stop")
        self.stop()
        print("container prune")
        do_cmd("""docker container prune -f""")

        print("image rm")
        do_cmd("""docker image rm {service_type}""".format(service_type=self.args.service_type))
        print("image prune")
        do_cmd("""docker image prune -f""")

    def compose(self):
        """
        docker compose服务
        :return:
        """
        print("start")
        cmd = "docker-compose -f {compose_yml} up -d ".format(compose_yml=self.args.docker_compose_yml)
        if self.args.service_type:
            cmd += " {service_type}".format(service_type=self.args.service_type)
        do_cmd(cmd)


if __name__ == "__main__":
    cur_path = os.path.dirname(os.path.realpath(__file__))
    p = argparse.ArgumentParser()
    p.add_argument('command', type=str, help="support this command: start/stop/clear")
    p.add_argument('--consul_url', type=str, default="10.0.22.120:8500", help="consul host url", required=False)
    p.add_argument('--service_type', type=str, default="gateway", help="service name", required=False)
    p.add_argument('--volume', type=str, default="disable",
                   help="whether to enable the volume, enable/disable", required=False)
    p.add_argument('--domain', type=str, default="", help="domain for certs generator", required=False)
    p.add_argument('--email', type=str, default="", help="email for certs generator", required=False)
    p.add_argument('--docker_file', type=str, default=os.path.join(cur_path, "Dockerfile"),
                   help="the path for the docker_file", required=False)
    p.add_argument('--docker_compose_yml', type=str, default=os.path.join(cur_path, "docker-compose.yml"),
                   help="the path for the docker_file", required=False)

    pargs = p.parse_args()
    print("pargs,", pargs)

    obj = IService(pargs)
    if hasattr(obj, pargs.command):
        getattr(obj, pargs.command)()
    else:
        print(p.format_usage())
        exit(1)
