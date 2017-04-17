local route = require('router')
local template = require "resty.template" 
local json = require('rapidjson')
template.caching(true)
local format = string.format
local ngx_header  = ngx.header
local r = route.new()
local stock_cache = ngx.shared.stock_cache
local db = nil
local len = string.len
local ngx_req = ngx.req
local md5 = ndk.set_var.set_md5
ngx_req.read_body()
ngx_header.content_type = 'text/html'
local redis

local function json_suc(err,err_code,arr)
  ngx_header.content_type = "application/json"
  ngx.status = 200
  ngx.say(json.encode({['status'] = err_code, ['message'] = err,['result'] = arr}))
end
local function json_error(err,err_code)
    json_suc(err,err_code,nil) 
end
local function auth_check()
    local headers = ngx_req.get_headers()
    local authToken = headers['Authorization'];
    redis = require("redis_db").new()
    redis:select(2)
    local ok = redis:hexists('login:',authToken)

    if ok ~= 1 then
        json_error('未登录',400)
        ngx.exit(200)
    end
    local _str  = redis:hget('login:',authToken)
    if not _str then    
         json_error('未登录',400)
        ngx.exit(200)
    end
    local res = json.decode(_str)
     if not res then    
         json_error('未登录',400)
        ngx.exit(200)
    end
    return res['id'];
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
  sql = format("update cc_user set total_login = total_login + 1 ,login_IP = '%s' , login_time = localtime() ",ip)
  local res  = db:query(sql)
  local token = md5(res[1]['id'])
  local redis = require('redis_db').new()
  redis:select(2)
  redis:hset("login:",token,json.encode(res[1]))
  redis:select(0)
  json_suc('登录成功',200,{['token'] = token,['userID'] = res[1]['id']})
end
local function register(username,password,mobile)
    open_mysql()
    local res,err = db:query(format('select id from cc_user where username = %s',username))
    if not res or #res > 0 then
      json_error('用户已存在',400)
      return true
    end
    local sql = format("insert into cc_user(username,password,mobile,reg_time) values(%s,'%s',%s,localtime())",username,password,mobile or "''")
    local res, err = db:query(sql)
    if not res then
      json_error("注册失败",400)
      return false
    end
    json_suc('注册成功',200)
    return true
end
r:match('GET','/user/info',function(params)
      local user_id = auth_check()
      local info, err = redis:hget("login:",md5(user_id))
      if not info then
          json_error('error',400)
      end
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
    local username = ndk.set_var.set_quote_sql_str(args['username'] or '')
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
r:match('POST','/user/register',function()
    local err =''
    local err_code = 200
    local args = ngx_req.get_uri_args()
    --local args =  ngx_req.get_post_args()
    local username = ndk.set_var.set_quote_sql_str(args['username'] or '')
    local pass = args['password'] or ''
     if len(username)  < 3 then
        err = '用户名长度不够'
        err_code = 400
    elseif len(pass) < 6 then
        err ='密码长度不够'
        err_code = 400
    end
    if err_code ~=  200 then
         json_error(err,err_code)
         return true
    end
    local password = md5(pass)
    register(username,password)
    return true

end)
r:match('POST','/user/category',function()
    local args = ngx_req.get_post_args()
    local user_id = auth_check()
    local name = args['name'] or ''
    local err = ''
    local err_code = 200
    if len(name) == 0 then
        err_code = 400
        err = '非法访问'
    end
    if err_code ~= 200 then
        json_error(err,err_code)
    end
    open_mysql()
    local sql = format("insert into cc_stockGroup(name,uid,created_at,status,public) values(%s,%d,localtime(),1,1);",ndk.set_var.set_quote_sql_str(name),user_id);
    local res, err = db:query(sql)
    if not res or res.affected_rows ==0 then
      json_error('保持失败',400)
    end
    json_suc('保存成功',200) 
    ngx.eof()
    res, err = db:query('select id,name from cc_stockGroup where uid = '..user_id .. ' and status =1')
    redis:set('usr:'..user_id ..':stockGroup',json.encode(res))

end)

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
    local res, err = redis:get('usr:'..user_id ..':stockGroup')
    json_suc('success',200,res or '')
end)
local function update_stock_cache(sg_id)
    local sql = "select id,cpy_id from cc_user_stock where status = 1 and sg_id = " ..sg_id

     local res, err, errno, sqlstate = db:query(sql)
      
      if res  then
            local _t = {}
            for _,v in ipairs(res) do
              _t[tostring(v['cpy_id'])] = v['id']
            end
            redis:set(format('us:%d',sg_id),json.encode(_t))
      end

end
r:match('DELETE','/user/favor/:sg_id/:cpy_id',function(params)
    local sg_id = tonumber(params.sg_id)
    local cpy_id = ndk.set_var.set_quote_sql_str(tostring(params.cpy_id))
    local uid = auth_check()
    open_mysql()
    local sql = format("update cc_user_stock set status = 0 where sg_id = %d and cpy_id = %s and uid = %d ;",sg_id,cpy_id,uid)
    local res, err, errno ,sqlstate = db:query(sql)
    if not res or res.affected_rows == 0 then
        json_error(sql,400)
        return 
    end
    json_suc("删除成功" ,200)
    update_stock_cache(sg_id)
end);
r:match('POST','/user/favor/:cpy_id',function(params)
    local args = ngx_req.get_post_args()
    local sg_id = tonumber(args['sg_id'] or 0)
    local user_id = auth_check()
    if sg_id <= 0 then
       json_error('参数错误',400)
       ngx.exit(200)
    end
    local sql = format("select id from cc_user_stock where sg_id = %d and cpy_id = %s and uid = %d and status =1 limit 1;",sg_id,ndk.set_var.set_quote_sql_str(tostring(params.cpy_id)),user_id)
    open_mysql()
    res, err, errno, sqlstate = db:query(sql)
    if res and #res > 0 then
        json_error("已订阅",400)
        return true
    end

    sql = format("insert into cc_user_stock(uid,cpy_id,created_at,sg_id) values(%d,%s,localtime(),%d);",user_id,ndk.set_var.set_quote_sql_str(tostring(params.cpy_id)),sg_id)
    res, err, errno, sqlstate = db:query(sql)
    if not res then
       json_error('添加失败',400)
       ngx.eof()
       ngx.log(ngx.ERR,err .. ' ' ..sqlstate)
       return true
    end

   
    if res.affected_rows >  0 then
      json_suc('添加成功',200)
      update_stock_cache(sg_id)
    end
    return true
end);
local ok, errmsg = r:execute(
        ngx.var.request_method,
        ngx.var.uri,
        ngx_req.get_uri_args(),  -- all these parameters
        ngx_req.get_post_args()
)         -- into a single "params" table
      if ok then
          ngx.status = 200
          close_mysql()
      else
          ngx.status = 200
          ngx.say(errmsg)
          ngx.log(ngx.ERR, errmsg)
      end