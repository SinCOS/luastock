local route = require("router").new()
local json = require("rapidjson")
local format = string.format

local mysql

local function open_mysql()
	local db = require("resty.mysql").new()
	db:set_timeout(1000)
	local ok, err , errno , sqlstate = db:connect{
		host = "127.0.0.1",
		port = 3306,
		database = 'stock',
		user = 'root',
		password = '123456',
		max_packet_size = 1024 * 1024
	}
	if not ok then
		ngx.say('failed to connect: ', err, " ", errno, " : ", sqlstate)
	end
	mysql = db
end
local function close_mysql()
	if mysql then
		mysql:set_keepalive(10000,100)
	end
end
route:match('GET','/stock/:cpy_id',function(params)
	local redis = require("redis_db").new()
	if not mysql then open_mysql() end 
	ok, err, errcode, sqlstate = mysql:query(format("select * from cc_daily where cpy_id = %s order by id desc ;",ndk.set_var.set_quote_sql_str(params.cpy_id)))
	--ngx.say(format("select * from cc_daily where cpy_id = %s ;",ngx.quote_sql_str(params.cpy_id)))
	if  ok then 
		ngx.say(json.encode(ok))
	else
		ngx.say(err,sqlstate)
	 end
end)
route:match('GET','/stock/:cpy_id/info',function(params)

end)


function main()
  ngx.req.read_body()
  local ok, errmsg = route:execute(
        ngx.var.request_method,
        ngx.var.uri,
        ngx.req.get_uri_args(),  -- all these parameters
        ngx.req.get_post_args()
)         -- into a single "params" table

      if ok then
          ngx.status = 200
      else
          ngx.status = 200
          ngx.say(errmsg)
          ngx.log(ngx.ERR, errmsg)
      end
end
ngx.header.content_type = "application/json"
local ok, err = pcall(main)
close_mysql()
if not ok then ngx.say(err) end