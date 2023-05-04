# api-gateway-by-openresty
    
    基于OpenResty（nginx+lua）+ kubernetes 的API网关。
 
    
    提供端口：
       80端口，http协议
       443端口，https协议，需要经过帐号服务授权
       663端口，https协议，不需要经过帐号服务授权，纯静态链接
 
    This container provides an Nginx application with Let's Encrypt certificates 
    generated at startup, as well as renewed (if necessary) and Nginx gracefully restarted.
    


# 相关路径
    
    openresty配置文件：/usr/local/openresty/nginx/conf
    
    lua授权鉴权脚本： /usr/local/openresty/lualib/auth/
 
# 构建   
    
    docker build -t gateway:3.0.0 --no-cache .
    
# k8s api权限授予

   给默认的default的serviceaccount账号创建一个view的角色：

        kubectl create clusterrolebinding default-crb --clusterrole=view --serviceaccount=default:default
        
        
# 网关机制
    
    通过获取service， service对应的pod，直接生成upstream方式，
    
    也可以使用service直接走k8s的dns功能，坏处是速度肯定慢一些。
