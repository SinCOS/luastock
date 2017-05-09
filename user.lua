local route = require('router')
-- local template = require "resty.template" 
local json = require('rapidjson')
local validation = require('resty.validation')
local cookie = require('resty.cookie'):new()
local config_cache = ngx.shared.stock_config
-- template.caching(true)
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
local ngx_time = ngx.time
ngx_req.read_body()
ngx_header.content_type = 'text/html; charset=utf-8'
local redis
local  expires_time = 72 * 3600 
local function json_suc(err,err_code,arr)
  ngx_header.content_type = "application/json; charset=utf-8"
  ngx.status = err_code
  ngx.say(json.encode({['status'] = err_code, ['message'] = err,['result'] = arr}))
end
local function json_error(err,err_code)
    json_suc(err,err_code,nil) 
end
local function get_auth_token()
     local headers = ngx_req.get_headers()
     local authToken = headers['Authorization'];
    return authToken or '';
end
local function auth_check()
    local headers = ngx_req.get_headers()
    local authToken = headers['Authorization'];
    if not authToken then
        authToken = cookie:get('Authorization')
    end
    if not authToken then
        json_error('未登录',404)
        ngx.exit(404)
    end
    redis = require("redis_db").new()
    redis:select(2)
    local ok = redis:exists(format('token:%s',authToken))

    if ok ~= 1 then
        json_error('未登录',404)
        ngx.exit(404)
    end
    local _str  = redis:get(format('login:%s',authToken))
    if not _str then    
         json_error('未登录',404)
         ngx.exit(404)
    end
    return _str,authToken;
end
local function open_mysql()
  if db then return db end
  local mysql = require('resty.mysql')
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
local function login(username,password)
  open_mysql()
  local sql = format("select * from cc_user where username = %s and password = '%s' ",username,password)
  local ip = ngx.var.remote_addr 

  local res, err ,errno , sqlstate = db:query(sql)
  if not res  then return json_error(err .. " " .. sqlstate) end
  if #res == 0 then
      json_error('登陆失败',400)
      return 
  end
  local user_id = res[1]['id']
  sql = format("update cc_user set total_login = total_login + 1 ,login_IP = '%s' , login_time = localtime()  where id = %d ",ip,user_id)
  db:query(sql)
  local token = md5(ip .. user_id)
  local redis = require('redis_db').new()
  redis:select(2)
  local login_key = format('login:%s',token)
  local token_info = format('token:%s',token)
  local current_time = ngx_time()
  redis:init_pipeline()
  redis:set(format('login:%s',token),user_id)
  redis:expire(login_key,current_time+expires_time)
  redis:set(token_info,json.encode(res[1]))
  redis:expire(token_info,current_time+expires_time)
  redis:commit_pipeline()
  redis:select(0)

  cookie:set({
      key = 'Authorization', value = token,
      path = '/',
      expires = ngx.cookie_time(current_time+ expires_time)
  })
  json_suc('登录成功',200,{['token'] = token,['userID'] = user_id})
end
local function register(username,password,email,mobile)
    open_mysql()
    local user = sql_str(username)
    local em = sql_str(email)
    local res,err = db:query(format('select username from cc_user where username = %s  or email = %s limit 1;',user,em))
    if not res  then
         json_error('系统错误，请联系管理员',400)
      return true
    elseif #res > 0 then
       if res[1]['username'] == username then
         err = '用户已存在'
      else
        err = '电子邮箱已被注册'
      end
      json_error(err,400)
      return true
    end
    local sql = format("insert into cc_user(username,email,password,mobile,reg_time) values(%s,%s,'%s',%s,localtime())",user,em,password,mobile or "''")
    local res, err = db:query(sql)
    if not res then
      json_error(err,400)
      return false
    end
    json_suc('注册成功',200)
    return true
end
r:match('GET','/user/logoff',function()
    local user_id,token = auth_check()
    redis:init_pipeline()
    redis:del(format('login:%s',token))
    redis:del(format('token:%s',token))
    redis:commit_pipeline()
    return true
end)
r:match('GET','/user/info',function(params)
      local user_id,token = auth_check()
      local info, err = redis:get(format('login:%s',token))
      if not info then
          json_error('error',400)
      end
      local info =  redis:get(format('token:%s',token))
      local user_info = json.decode(info)
      local _send = {
        ['username'] = user_info['username'],
        ['id'] = user_info['id']
      }
      json_suc('success',200,_send)
end)
r:match('POST','/user/login',function(params)
    --local args = ngx_req.get_uri_args()
    local args = ngx_req.get_post_args()
    local username = ndk_set.set_quote_sql_str(args['username'] or '')
    local pass = args['password'] or ''
    local err,err_code
    if len(username)  < 3 then
        err = '用户名长度不够'
        err_code = 400
    elseif len(pass) < 6 then
        err ='密码长度不够'
        err_code = 400
    end
    return login(username,ngx.md5(pass))

end);
local verify = {
    nick = validation.string.trim:minlen(4),
    email = validation.string.trim.email,
    password = validation.string.trim:minlen(6)
}
r:match('POST','/user/register',function(args)
    local err =''
    local err_code = 200
    --local args = ngx_req.get_uri_args()
    local vu,username = verify.nick(args['username'] or '')
    local vp,pass = verify.password(args['password'] or '')
    local ve,email =  verify.email(args['email'] or '')
     if  not vu then
       err_code = 400
       err = '请输入正确的用户名'
    elseif not vp  then
        err_code  = 400
        err = '密码长度不能小于6个字符'
    elseif not ve then
        err_code = 400
        err = '电子邮箱格式不对'
    end
    if err_code ~=  200 then
         json_error(err,err_code)
         return true
    end
    local password = md5(pass)
    register(username,password,email)
    return true

end)
r:match('POST','/user/category',function(args)
    local user_id = auth_check()
    
    local ok,name = validation.trim(args['name'] or '') 
    local err = ''
    local err_code = 200
    if not ok or  len(name) == 0 then
        err_code = 400
        err = '非法访问'
    end
    if err_code ~= 200 then
        json_error(err,err_code)
        return true
    end
    open_mysql()
    local sql = format("insert into cc_stockGroup(name,uid,created_at,status,public) values(%s,%d,localtime(),1,1);",ndk_set.set_quote_sql_str(name),user_id);
    local res, err = db:query(sql)
    if not res or res.affected_rows ==0 then
      json_error('保持失败',400)
      return true
    end
    json_suc('保存成功',200) 
    ngx.eof()
    res, err = db:query('select id,name from cc_stockGroup where uid = '..user_id .. ' and status =1')
    redis:set('usr:'..user_id ..':stockGroup',json.encode(res))

end)
local function update_stockGroup(user_id,delete)
    open_mysql()
    local del = delete or false
    local _key = 'usr:'..user_id ..':stockGroup'
    local re, err 
    if del then
       re, err =  db:query(format('update cc_stockGroup set status = 0  where uid = %d and id = %d ',user_id,del))
       if not re or re.affected_rows == 0 then
            return false,err
       end 
     
    end

    local sql = format("select id,name from cc_stockGroup where uid = %d  and status > 0 ",user_id)
    re, err = db:query(sql)
    res = json.encode(re)
   
    local ok, err = redis:set(_key,res)

    redis:expire(_key,ngx_time()+3600*24*3)
    return res 
end
r:match('GET','/user/category',function()
    -- local args = ngx.get_post_args()
    -- if not args or nil == args['name'] then
    --     json_error("非法访问"，400)
    --     return true
    -- end
    local user_id = auth_check()
    -- local group_name = args['name']
    -- local sql = format("insert into cc_stockGroup(name,uid,created_at) values(%s,%d,localtime());",group_name,user_id)
    -- open_mysql()
    -- local res, err, errno, sqlstate = db:query(sql)
    -- if not res and res.affected_rows == 0  then
    --     json_error('保存失败',400)
    --     return true
    -- end

    --local redis = require('redis_db').new()
    local _key = 'usr:'..user_id ..':stockGroup'
    local res, err = redis:get(_key)
    if not res then
        res = update_stockGroup(user_id)
    end
    json_suc('success',200,res or '')
end)
r:match('PUT','/user/group/rename/:sg_id',function(args)
    local sg_id = tonumber(args.sg_id)
    local name = args['name'] or ''
    local ok , err = validation.string.trim.len(2)
    ngx.say(ok,err)
end)
r:match('DELETE','/user/group/:sg_id',function(params)
    local sg_id = tonumber(params.sg_id);
    local user_id = auth_check()
    local res, err = update_stockGroup(user_id,sg_id)
    if not res then 
        json_error('操作失败',500,debug and res or nil)
        return true
    end    
    json_suc('删除成功',200)
end)
r:match('DELETE','/user/favor/:sg_id/:cpy_id',function(params)
    local sg_id = tonumber(params.sg_id)
    local cpy_id = params.cpy_id
    local user_id = auth_check()
    local res, err = redis:srem(format('usr:%d:us:%d',user_id,sg_id),cpy_id)
    if res and tonumber(res) > 0 then
        json_suc("删除成功" ,200)
        ngx.eof()
        open_mysql()
        local sql = format("update cc_user_stock set status = 0 where sg_id = %d and cpy_id = %s and uid = %d ;",sg_id,cpy_id,user_id)
        db:query(sql)
    else
        json_error("操作失败",500)
    end
    return true
    --update_stock_cache(sg_id)
end);
r:match('POST','/user/favor/:cpy_id',function(params)
    local args = ngx_req.get_post_args()
    local sg_id = tonumber(args['sg_id'] or 0)
    local user_id = auth_check()
    if sg_id <= 0 then
       json_error('参数错误',500)
       ngx.exit(200)
    end
   local ok , err = redis:sadd(format('usr:%d:us:%d',user_id,sg_id),params.cpy_id)


   if tonumber(ok) > 0 then
        json_suc('添加成功',200)
        ngx.eof()
        open_mysql()
        sql = format("insert into cc_user_stock(uid,cpy_id,created_at,sg_id) values(%d,%s,localtime(),%d);",user_id,ndk_set.set_quote_sql_str(params.cpy_id),sg_id)
        res, err, errno, sqlstate = db:query(sql)
    else
        json_error("添加失败",500)
    end
    -- local sql = format("select id from cc_user_stock where sg_id = %d and cpy_id = %s and uid = %d and status =1 limit 1;",sg_id,ndk_set.set_quote_sql_str(tostring(params.cpy_id)),user_id)
    -- open_mysql()
    -- res, err, errno, sqlstate = db:query(sql)
    -- if res and #res > 0 then
    --     json_error("已订阅",400)
    --     return true
    -- end

    -- sql = format("insert into cc_user_stock(uid,cpy_id,created_at,sg_id) values(%d,%s,localtime(),%d);",user_id,ndk_set.set_quote_sql_str(tostring(params.cpy_id)),sg_id)
    -- res, err, errno, sqlstate = db:query(sql)
    -- if not res then
    --    json_error('添加失败',400)
    --    ngx.eof()
    --    ngx.log(ngx.ERR,err .. ' ' ..sqlstate)
    --    return true
    -- end

   
    -- if res.affected_rows >  0 then
    --   json_suc('添加成功',200)
    --   update_stock_cache(sg_id)
    -- end
    return true
end);
local function build_param(param)
    local _t = {}
    for k,v in pairs(param) do 
            table.insert(_t,format('%s=%s',k,tostring(v)))
    end
    return table.concat( _t, "&")
end
local function month_price (month)
    if month == 1 then return 0.01 end
    if month == 3 then return 55 end
    if month == 6 then return 110 end
    if month == 12 then return 200 end
    json_error('参数错误',404)
    ngx.exit(404)
end
r:match('GET','/user/666',function(param)
    auth_check()
    redis:select(1)
    local res = redis:get('orderInfo')
    local tb =json.decode(res)
    ngx.say(build_param(tb))
end)
r:match('GET','/user/vip/order',function(param)
    local month = tonumber(param['month'] or (json_error('参数错误',404) or ngx.exit(404)))
    local sql = format('select ')
    local user_id = auth_check()
    local price = month_price(month)
    local body = {
        ['orderID'] = ngx_time(),
        ['title'] = '主力追踪会员服务',
        ['total'] = price,
        ['user_id']  = user_id,
        ['body'] ="主力追踪会员服务",
        ['notify_url'] ="http://www.zhulizhuizong.com/user/vip/order/notify",
        ['return_url'] = "http://www.zhulizhuizong.com"
    }
    open_mysql()
    local sql = format("insert into cc_userVip(orderID,uid,created_at,total,status,month) values('%s',%d,unix_timestamp(),%f,0,%d)",body['orderID'],user_id,body['total'],month)
    local ok, sqlerr =  db:query(sql)
    if not ok or ok.affected_rows ==0 then
        json_error('系统错误',404)
        return true
    end
    local http = require('resty.http').new()
    local res, err = http:request_uri('http://www.lxrs.net/alipay/api.php',{
          method = "POST",
          body = build_param(body),
          headers = {
                ['Content-type'] = 'application/x-www-form-urlencoded'
          }
    })
    if not res then 
        ngx.say('666',err)
    end
   

end)
r:match('GET','/user/777',function(param)
    local user_id = auth_check()
    open_mysql();
    ngx.say(user_id)
    local ok ,err = db:query('select * from cc_user where id = '.. user_id ..' limit 1;')
    ngx.say(os.date("%x %X",ok[1]['viptime']))
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
