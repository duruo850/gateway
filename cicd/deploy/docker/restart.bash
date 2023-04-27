sudo docker rm $(sudo docker ps|grep gateway | awk '{print $1}')
sudo docker container prune -f

sudo docker run -d  --restart=always -p 1180:80 -e CONSUL_URL="10.0.22.120:8500" -v /home/qiteck/program/docker_service/gateway/consul_template/nginx.ctpl:/usr/local/bin/consul_template/nginx.ctpl gateway:2.1.3-bionic