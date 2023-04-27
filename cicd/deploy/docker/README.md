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
    
# 环境变量

    
    
# 启动
      
    如果有证书设置证书：
    -v /usr/local/openresty/nginx/cert/key.pem:/usr/local/openresty/nginx/cert/key.pem
    -v /usr/local/openresty/nginx/cert/key.pem:/usr/local/openresty/nginx/cert/primary.pem
    
    设置配置文件和脚本
    -v `pwd`/nginx.conf:/usr/local/openresty/nginx/conf/nginx.conf \
    -v `pwd`/lua/auth/auth.lua:/usr/local/openresty/lualib/auth/auth.lua \
    
        
    # 实例：不使用证书
    docker run -d  --restart=always -p 1080:80  -p 1553:553 -p 1663:663  -p 1773:773 -p 1783:783  gateway:3.0.0
    
    # 实例： 使用test2.magefitness.com的证书
    sudo docker run -d  --restart=always -p 1443:443 -p 1553:553 -p 1663:663  -p 1773:773   -p 1783:783   --network default_network-v /etc/letsencrypt_test2.magefitness.com/live/test2.magefitness.com/fullchain.pem:/usr/local/openresty/nginx/cert/primary.pem -v /etc/letsencrypt_test2.magefitness.com/live/test2.magefitness.com/privkey.pem:/usr/local/openresty/nginx/cert/key.pem duruo850/gateway:3.0.0
 
# 功能
* api认证
* api鉴权
* 后台web服务动态注册和发现
# 实现
#### 技术
    OpenResty（nginx+lua）：一个基于 Nginx 与 Lua 的高性能 Web 平台，其内部集成了大量精良的 Lua 库、第三方模块以及大多数的依赖项。用于方便地搭建能够处理超高并发、扩展性极高的动态 Web 应用、Web 服务和动态网关。  
    OpenResty 通过汇聚各种设计精良的 Nginx 模块（主要由 OpenResty 团队自主开发），从而将 Nginx 有效地变成一个强大的通用 Web 应用平台。这样，Web 开发人员和系统工程师可以使用 Lua 脚本语言调动 Nginx 支持的各种 C 以及 Lua 模块，快速构造出足以胜任 10K 乃至 1000K 以上单机并发连接的高性能 Web 应用系统。  
    consul：一个分布式的、可靠的键值存储系统，可以用来做配置管理，服务注册与发现。  
    consul_tenplate：consul配置模块，监听服务变化，有消息自动生成nginx.conf，然后重启nginx
    
#### 实现细节
1、基于nginx对外提供http、websocket服务；  
2、基于k8s coredns做服务注册与发现；    
3、nginx的NGX_HTTP_ACCESS_PHASE阶段，对请求进行处理（认证和鉴权实现）。  
  3.1 lua整合nginx，根据uri判断当前资源是否需要认证（即cookie是否存在）；  
  3.2若需要认证，拿cookie的信息到redis中查找相应的session信息，如果没有则表示无效的cookie，没有权限；否则再根据uri从redis拿该资源被哪些角色所拥有。然后根据当前用户的session中的角色信息与资源所属角色进行判断，即可以知道当前用户是否拥有权限，达到鉴权的目的。  
  3.3 将session中的信息（user_id、company_id等）放入到header中，后台业务逻辑处理可能会用到。    
#### 实施步骤（略）
    1、安装OpenResty;  
    2、安装lua-resty-template; 
        Install LuaRocks, the package manager for Lua modules. You can download the latest version from the LuaRocks website: https://luarocks.org/#quick-start
        Use LuaRocks to install lua-resty-template by running the following command:
        sudo luarocks install lua-resty-template
# 存在问题
  1、nginx启动时，默认upstream要有相应的配置（即存储upstream信息的文件servers_test.conf至少要有一条记录，可随意填一个不存在的后台进程，只要nginx启动好后，nginx会去拉取etcd中的信息，然后更新到该文件中）；  
  2、后台节点都下线或者挂掉之后，查看nginx中的upstream信息（/upstream_list），会至少存在一个后台节点信息（备注：跟nginx的upstream配置有关，即至少需要存在一个节点信息。影响不大，因为后台进程都挂掉了，即使upstream里面还存在一个节点，请求也会失败）；  
  3、restful uri转成资源的url（比较啰嗦）； 
  
  nginx关闭日志：access_log off; 
