local route = require('router')
local json = require('rapidjson')
local mysql = require('resty.mysql')
local redis = require("redis_db").new()
local config_cache = ngx.shared.stock_config
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
    host = config_cache:get('db:ip') or '127.0.0.1',
    port = config_cache:get('db:port') or 3306,
    database = config_cache:get('db:name'),
    user = config_cache:get('db:user') ,
    password = config_cache:get('db:pwd'),
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
local function vipTime(month,viptime)
    local curTime = viptime or ngx_time
    local timeTab = os.date("*t",curTime)
    ngx.say(timeTab['year'],timeTab['month'],timeTab['day'])
    if 12 - (timeTab['month'] + month) >= 0 then
        timeTab['month'] = timeTab['month'] + month
    else
        timeTab['month'] = 12 - (timeTab['month'] +month)
        timeTab['year'] = timeTab['year'] + 1
    end 
    return os.time(timeTab)
end
local function update_table(param)


end
r:match('POST','/user/vip/order/notify',function(param)
        ngx.status =200 
        if get_method() ~= 'POST'  then 
            ngx.say('fail','get_method')
            return true
         end
         if param['trade_status'] == 'TRADE_SUCCESS' then
        open_mysql()
        local orderID = param['out_trade_no']
        local total = tonumber(param['total_fee'])
        local buyer_email = param['buyer_email']
        local trade_no = param['trade_no']
        local sql = format("select * from cc_userVip where orderId= '%s' limit 1;",orderID);
        local user_res, err = db:query(sql)
        if not user_res or #user_res == 0 then 
            ngx.say('fail','cc_userVip',err,sql)
            return true
        end
        local order = user_res[1]
        if order['status'] == 0 and order['total'] == total and order['uid'] > 0  then
            local user_sql = format("select * from cc_user where id = %d ",order['uid'])
            ok , err = db:query(user_sql)
            if not ok or #ok == 0 then 
                ngx.say('fail')
                ngx.log(ngx.ERR,user_sql)
                return true
            end
            local user = ok[1]  -- get user info
            sql = format("update cc_userVip set status =1 ,buyer_email = '%s', trade_no ='%s',updated_at = unix_timestamp() where orderID ='%s' ",buyer_email,trade_no,orderID)
            ok ,err = db:query(sql)
            if not ok or ok.affected_rows == 0 then 
                ngx.say('fail')  -- update opreaton fail 
                ngx.log(ngx.ERR,'update cc_userVip')
                return true
            end
            local curNow = ngx_time
            if user['viptime'] > curNow  then
                curNow = user['viptime']
            end
            local viptime = vipTime(tonumber(order['month']),curNow)
            sql = format('update cc_user set viptime = %d where id = %d',viptime,order['uid'])
            local ok, res  = db:query(sql)
            if not ok or ok.affected_rows == 0 then 
                ngx.say('fail') 
                return true
            end 
            ngx.say('success')
            return true
        end
        ngx.say('fail')
        return true
        end
          ngx.say('fail')
end)

local function main()
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
end

local ok, err  = pcall(main)

if not ok then ngx.say(err) end
