local uri = ngx.var.uri

-- run circul-breaker
local cb = require "auth/circuit_breaker"
cb:run_access()

-- auths url not need to check authorization
local auth_urls = {{"/account/v1/authorization", "GET"}, {"/account/v1/phone", "GET"}, {"/account/v1/user_name", "GET"}, {"/account/v1/sms_code", "POST"}, {"/account/v1/user", "POST"}, {"/account/v1/authorization", "POST"}, {"/account/v1/password", "PUT"}, {"/account/v1/email", "GET"}, {"/account/v1/email_code", "POST"}, {"/account/v1/account", "GET"}, {"/account/v1/code", "POST"} }

for k,v in ipairs(auth_urls) do
    if uri == v[1] and ngx.req.get_method() == v[2] then
        return
    end
end

local cjson = require "cjson"
local headers = ngx.req.get_headers()

-- check header: if not user key and app key, 401 will return
if headers["Key"] == nil and headers["AppKey"] == nil  then
    ngx.log(ngx.INFO,"verify falied, header invalid, uri,", ngx.var.uri, "headers,", cjson.encode(headers))
    ngx.status = 401
    ngx.print("")
    ngx.exit(401)
    return
end

-- check account authorization
local res = ngx.location.capture("/account/v1/authorization", {method=ngx.HTTP_GET, headers=headers});
-- ngx.log(ngx.INFO, "/user/v1/authorization res, status:", res.status, ", body: ", res.body, ", headers: ", cjson.encode(headers))

-- check status
if res.status ~= 200  then
    ngx.log(ngx.INFO,"verify falied, status error:", res.status, "uri,", ngx.var.uri, "headers,", cjson.encode(headers))
    ngx.status = 401
    ngx.print(res.body)
    ngx.exit(401)
    return
end

local res_body = cjson.decode(res.body)
if not res_body then
    ngx.log(ngx.INFO,"verify falied, not res_body, uri,", ngx.var.uri, "headers,", cjson.encode(headers))
    ngx.status = 401
    ngx.print(res.body)
    ngx.exit(401)
    return
end

local data = res_body['data']
if not data then
    ngx.log(ngx.INFO,"verify falied, not data, uri,", ngx.var.uri, "headers,", cjson.encode(headers))
    ngx.status = 401
    ngx.print(res.body)
    ngx.exit(401)
    return
end

-- check user_id
local user_id = data['user_id']
if not user_id then
    ngx.log(ngx.INFO,"verify falied, not user_id, uri,", ngx.var.uri, "headers,", cjson.encode(headers))
    ngx.status = 401
    ngx.print(res.body)
    ngx.exit(401)
end

-- add user_id to header，clear other auth headers
ngx.req.set_header("User-Id", user_id)


-- check user_info
local user_info = data['user_info']
if user_info then
    -- add user_info to header
    ngx.req.set_header("UserInfo", cjson.encode(user_info))
end


-- check auth_info
local auth_info = data['auth_info']
if auth_info then
    -- add auth_info to header
    ngx.req.set_header("AuthInfo", cjson.encode(auth_info))
end


ngx.req.clear_header("Key")
ngx.req.clear_header("Version")
ngx.req.clear_header("Time")
ngx.req.clear_header("Token")

