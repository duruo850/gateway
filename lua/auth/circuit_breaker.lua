--  a Circuit breaker for URL
local lib = require "auth/jsonlib"

local FUSE_END = "fuse_end"
local FAIL_COUNT = "fail_count"
local FUSE_TIMES = "fuse_times"
local HALF_OPEN = "half_open"
local BUCKET_ID = "bucket_id"


-- singleton in one process
local plugin = plugin or {
    VERSION = '1.0.0',

    REQUEST_TIMEOUT = 1, --in seconds, 请求超时时间，超过则算失败，记录下来请求失败的时间
    REQUEST_TIMEOUT_DICT = {['/ws']=2},   -- 特殊url的timeout配置
    FUSED_DURATION = 10, --in seconds, 失败持续时间，中间是半开或者全开
    FAILS_LIMIT = 10, --number of consecutive failures, 连续故障数
    LIFETIME = 15, -- expired counters will be discarded, in seconds, 过期的计数器将被丢弃
    DEBUG = false,


    GEN_BUCKET_ID_FUNC = function(self)
        return table.concat({ ngx.var.host, ngx.var.uri })
    end,

    ON_DEGRADED_CALLBACK = function(self)
        ngx.status = 403
        return ngx.exit(403)
    end,

    BEFORE_HALF_OPEN_CALLBACK = function(self)
    end,

    AFTER_HALF_OPEN_CALLBACK = function(self)
    end,

    REQUEST_TIMEOUT_FUNC = function(self)
        local timeout = self.REQUEST_TIMEOUT_DICT[ngx.var.uri]
        if timeout ~= nil then
            return timeout
        end
        return self.REQUEST_TIMEOUT
    end,

    VALIDATE_REQUEST_FUNC = function(self)
        local elapsed = ngx.now() - ngx.req.start_time()
        local is_valid = elapsed < self:REQUEST_TIMEOUT_FUNC()
        return elapsed, is_valid
    end,

    dict = ngx.shared.fuse_shard_dict,
}

function plugin:wrap_key(key)
    return table.concat({ ngx.ctx[BUCKET_ID], '@', key })
end

function plugin:incr(key, add, init, expire)
    return self.dict:incr(ngx.ctx[key], add, init, expire)
end

function plugin:get(key)
    return self.dict:get(ngx.ctx[key])
end

function plugin:set(key, val)
    return self.dict:set(ngx.ctx[key], val)
end

function plugin:setup(fn_config)
    fn_config(self)
    self:debug("debug is enabled, dict len: ", #self.dict, "  ", " REQUEST_TIMEOUT: ", self.REQUEST_TIMEOUT, " FUSED_DURATION: ", self.FUSED_DURATION, " LIFETIME: ", self.LIFETIME, " FAILS_LIMIT: ", self.FAILS_LIMIT)
end

function plugin:run_access()
    local ctx = ngx.ctx

    --need lazy-calculating
    ctx[BUCKET_ID] = self:GEN_BUCKET_ID_FUNC()
    ctx[FAIL_COUNT] = self:wrap_key(FAIL_COUNT)
    ctx[FUSE_END] = self:wrap_key(FUSE_END)
    ctx[FUSE_TIMES] = self:wrap_key(FUSE_TIMES)
    ctx[HALF_OPEN] = self:wrap_key(HALF_OPEN)

    if self:is_fused() then
        self:debug('is fused')
        ctx.fused = 1
        self:ON_DEGRADED_CALLBACK()
    elseif self:is_half_open() then
        self:debug('is half-open')
        ctx.fused = 1
        self:ON_DEGRADED_CALLBACK()
    elseif self:exiting_fused() then
        self:debug('enable half-open, and pass through')
        ctx.half_open = 1
        self:enable_half_open()
        self:BEFORE_HALF_OPEN_CALLBACK()
    end
end

function plugin:run_log()
    if ngx.ctx.fused == 1 then
        self:debug("fused, break by_log")
        return
    end
    local request_time, is_valid = self:VALIDATE_REQUEST_FUNC()
    if is_valid then
        self:reset_counters()
        self:debug('request success, will reset counters whether it is half-opening or not ')
    elseif self:is_half_open() then
        self:inspect_half_open_request()
        self:AFTER_HALF_OPEN_CALLBACK()
        self:debug('request timeout, in half-open', ',request_time: ', request_time, ',counters: ', lib:json(self:counters()))
    else
        local fail_count = self:count()
        self:debug('request timeout, not in half-open, fail_count: ', fail_count, ', request_time: ', request_time, ',counters: ', lib:json(self:counters()))
    end
end

function plugin:fused_times_add()
    self:debug(ngx.INFO,'fused times++')
    self:reset_counters(true, true)
end

function plugin:count()
    self:incr(FAIL_COUNT, 1, 0, self.LIFETIME)
    local fail_count = self:get(FAIL_COUNT)
    if fail_count == self.FAILS_LIMIT then
        self:debug("fails reaching the limit ")
        self:fused_times_add()
    end
    return fail_count
end

function plugin:reset_counters(set_fuse_end, incr_fuse_times)
    self:debug("reset counters, fuse_end: ", fuse_end, " fuse_times: ", fuse_times)
    if set_fuse_end == nil then
        self:set(FUSE_END, fuse_end)
    else
        self:set(FUSE_END, ngx.now() + self.FUSED_DURATION)
    end
    if incr_fuse_times == nil then
        self:set(FUSE_TIMES, fuse_times)
    else
        self:incr(FUSE_TIMES, 1, 0, 0)
    end
    self:set(FAIL_COUNT, nil)
    self:set(HALF_OPEN, nil)
end

function plugin:inspect_half_open_request()
    if ngx.ctx.half_open == 1 then
        self:debug("failed in half-open, fused++")
        self:fused_times_add()
    end
end

function plugin:exiting_fused()
    local fuse_end = self:get(FUSE_END)
    return fuse_end ~= nil and fuse_end < ngx.now()
end

function plugin:is_fused()
    local fuse_end = self:get(FUSE_END)
    return fuse_end ~= nil and fuse_end >= ngx.now()
end

function plugin:is_half_open()
    local half_open = self:get(HALF_OPEN)
    return half_open ~= nil and half_open > 0
end

function plugin:enable_half_open()
    return self:set(HALF_OPEN, 1)
end

function plugin:counters(bucket_all)
    local keys
    if bucket_all == false or bucket_all == nil then
        keys = {
            FUSE_END,
            FAIL_COUNT,
            FUSE_TIMES,
            HALF_OPEN,
        }
    else
        keys = self.dict:get_keys()
    end
    local dict = {}
    for _, v in pairs(keys) do
        dict[v] = self:get(v)
    end
    dict[BUCKET_ID] = self.GEN_BUCKET_ID_FUNC()
    local free_bytes = self.dict:free_space()
    dict['free_bytes'] = free_bytes
    return dict
end

function plugin:debug(...)
    if self.DEBUG then
        local temp = { ... }
        ngx.log(ngx.INFO, table.concat(temp, " "))
    end
end

return plugin
