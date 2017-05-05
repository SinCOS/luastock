local route = require('router')
local json = require('rapidjson')
local mysql = require('resty.mysql')
local redis = require("redis_db").new()
local format = string.format
local ngx_header  = ngx.header
local r = route.new()
local stock_cache = ngx.shared.stock_cache
local db = nil
local len = string.len
local ngx_req = ngx.req
local ndk_set = ndk.set_var
local md5 = ndk_set.set_md5
local debug = false
local sql_str = ndk_set.set_quote_sql_str
local get_method = ngx.req.get_method 
local ngx_time = ngx.time()
ngx_req.read_body()
ngx_header.content_type = 'text/html; charset=utf-8'

local function open_mysql()
  if db then return db end

  db,err = mysql:new()
  if not db then
      ngx.say(err)
      ngx.status = 200
      ngx.exit(200)
  end
  local ok, err, errno, sqlstate = db:connect{
    host ='127.0.0.1',
    port = 3306,
    database = 'stock',
    user = 'root',
    password = '123456',
    max_packet_size = 1024 * 1024
  }
   if not ok then
      ngx.say('failed to connect: ', err, ":" , errno, " ", sqlstate)
      ngx.status = 200
      ngx.exit(200)
      return 
  end
  return db

end
local function close_mysql()
  if db then
  return db:set_keepalive(10000,100)
  end
end
r:match('POST','/user/vip/notify',function(param)

        ngx.status =200 
        if get_method ~= 'POST' then 
            ngx.say('fail')
            return true
         end
        open_mysql()
        local orderID = param['out_trade_no']
        local total = param['total_fee']
        local sql = format("select * from cc_userVip where orderId= '%s' ",orderId);
        local ok, err = db:query(sql)
        if not ok or #ok == 0 then 
            ngx.say('fail')
            return true
        end
        local order = ok[1]

        if tonumber(order['status']) == 0 and order['total'] == total and order['uid'] > 0  then
            local user_sql = format("select * from cc_user where id = %d ",order['uid'])
            ok , err = db:query(user_sql)
            
            sql = format("update cc_userVip set status =1 ,buyer_email = '%s', trade_no ='%s',updated_at = unix_timestamp() ",order['buyer_email'],order['trade_no'])
            ok ,err = db:query(sql)
            
            if not ok or ok.affected_rows == 0 then ngx.say('fail') end
            local vipTime = ngx_time + 666
            sql = format('update cc_user set viptime = %d where id = %d',order['uid'])
        end

        
        redis:select(1)
        redis:set('orderInfo',json.encode(param))
        resis:set('ip', ngx.var.remote_addr )
        ngx.say('success')
end)


local ok, errmsg = r:execute(
        ngx.var.request_method,
        ngx.var.uri,
        ngx_req.get_uri_args(),  -- all these parameters
        ngx_req.get_post_args()
)         -- into a single "params" table
      if ok then
          close_mysql()
          ngx.exit(ngx.status)
      else
          ngx.status = 500
          ngx.say(errmsg)
          ngx.log(ngx.ERR, errmsg)
      end
