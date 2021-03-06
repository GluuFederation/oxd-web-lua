local http = require "resty.http"
local cjson = require "cjson.safe"

local function execute_http(oxd_host, command, token, jsonBody)
    ngx.log(ngx.DEBUG, "Executing command: ", command)
    local httpc = http.new()
    local headers = {
        ["Content-Type"] = "application/json"
    }

    if token ~= nil then
        headers.Authorization = "Bearer " .. token
        ngx.log(ngx.DEBUG, "Header token: ", headers.Authorization)
    end

    local res, err = httpc:request_uri(oxd_host .. "/" .. command, {
        method = "POST",
        body = jsonBody,
        headers = headers,
        ssl_verify = false
    })

    if err then
        ngx.log(ngx.ERR, "Host: ", oxd_host, "/", command, " Request_Body:", jsonBody, " error: ", err)
        return nil, "resty-http error: " .. err
    end

    ngx.log(ngx.DEBUG, "Host: ", oxd_host, "/", command, " Request_Body:", jsonBody, " response_body: ", res.body)

    local json, err = cjson.decode(res.body)
    if err then
        ngx.log(ngx.ERR, err)
        return nil, "JSON decode error: " .. err
    end
    res.body = json
    return res
end


-- all APIs below have next signature:
-- @param oxd_host: host/port of oxd server
-- @param params: request parameters to be encoded as JSON
-- @param token: access token
-- @return response:
local api_with_token = {
    "get_authorization_url",
    "get_tokens_by_code",
    "get_user_info",
    "get_logout_uri",
    "get_access_token_by_refresh_token",
    "uma_rs_protect",
    "uma_rs_check_access",
    "uma_rp_get_rpt",
    "uma_rp_get_claims_gathering_url",
    "update_site",
    "introspect_access_token",
    "introspect_rpt",
    "get_jwks",
    "get_rp",
}

-- @param oxd_host: host/port of oxd server
-- @param params: request parameters to be encoded as JSON
-- @return response:
local api_without_token = {
    "register_site",
    "get_client_token",
}

local _M = {}

for i= 1, #api_with_token do
    local api = api_with_token[i]
    local endpoint = api:gsub("_", "%-")
    _M[api] = function(oxd_host, params, token)
        local commandAsJson = cjson.encode(params)
        return execute_http(oxd_host, endpoint, token, commandAsJson)
    end
end

for i= 1, #api_without_token do
    local api = api_without_token[i]
    local endpoint = api:gsub("_", "%-")
    _M[api] = function(oxd_host, params)
        local commandAsJson = cjson.encode(params)
        return execute_http(oxd_host, endpoint, nil, commandAsJson)
    end
end

return _M
