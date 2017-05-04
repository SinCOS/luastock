local redis = require("redis_db").new()
local router = require('router').new()
local json = require('rapidjson')

local json_encode = json.encode
local json_decode = json.decode 



router:match('GET','/',function(params)

end)


router:match('POST','/vip/order',function(param)

end)


local function main()
  local ok, errmsg = router:execute(
        ngx.var.request_method,
        ngx.var.uri,
        ngx_req.get_uri_args(),  -- all these parameters
        ngx_req.get_post_args()
)         -- into a single "params" table

      if not ok then
          ngx.status = ngx.HTTP_OK
          ngx.say(errmsg)
          ngx.log(ngx.ERR, errmsg)
      end
      
      if redis then
        redis:select(0)
      end
      
end

local ok, err = pcall(main)

if not ok then ngx.say(err) end