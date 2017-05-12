local route = require('router')
local template = require "resty.template"
local redis = require("redis_db").new()
local json = require('rapidjson')
local format = string.format
local len = string.len
local byte = string.byte
local sub = string.sub
local tb_insert = table.insert
local ngx_req= ngx.req
template.caching(false)
ngx.header.content_type = 'text/html; charset=utf-8'
ngx_req.read_body()
local r = route.new()


local function get_Menu()
  redis:select(2)
  local _cache = redis:mget('publicGroup','vipGroup')
  local public , vip
  if _cache then
    public = ( type(_cache[1]) == 'userdata'  ) and {} or json.decode(_cache[1])
    vip = ( type(_cache[2]) == 'userdata'  ) and {} or json.decode(_cache[2])
  else
    public = {}
    vip = {}
  end

  return {
      title = "主力动向观测站",
      leftNav = true,
      url = {
      },
      Groups = {
          ['public'] = public,
          ['vip'] = vip
      }  
  }
end
r:match('GET','/',function()
   local menu = get_Menu()
   local view = template.new('view/index.html')
   view:render(menu)
   return true
end);

r:match('GET','/echarts',function()
  local menu = get_Menu()
  menu.leftNav = false
  local view = template.new('view/echarts.html')
  view:render(menu);
end)
r:match('GET','cache',function()
  ngx.say(ngx.today())
  redis:select(0)
  local cache = redis:get('last_news')
  ngx.say(cache);
end)
r:match('GET','/news',function(params)
  local menu = get_Menu()
  redis:select(0)
  local cache = redis:get('last_news')
  menu.news = json.decode(cache)
  menu.leftNav = false
  local view = template.new('view/news.html')
   view:render(menu)
end)
r:match('GET','/news/:id.html',function(params)

end)
r:match("GET",'/cache/:cpy_id',function(params)
local _current_time = ngx.time()
  local _current_table = os.date("*t",_current_time)
    local db_path = format('/usr/local/openresty/nginx/lua/%02d%02d.db',_current_table['month'],_current_table['day'])
    local db = require("lsqlite3").open(db_path)
    vm = db:prepare('select * from cc_stock_info where cpy_id = "'..params.cpy_id ..'" order by  id asc limit 100 ');
    local t ={}
    for row in vm:nrows() do 
        ngx.say(json.encode(row),'<br/>')
    end
     
end)
r:match('GET','/echarts_search',function(params)
  local args = ngx_req.get_uri_args()
  local stock_cache = ngx.shared.stock_cache
  local begin = args['begin'] or '09:15'
  local finish = args['finish'] or '13:00'
  local _type =  args['type'] == 'jlr' and 'jlr' or 'zlbfb'
  redis:select(0)
  local _ok , _err = redis:get('stock_count')
  local stock_count = tonumber(_ok or 0) *2 
  -- if byte(begin,1,1) == 48 then
  --     begin = sub(begin,2)
  -- end
  -- if byte(finish,1,1) == 48 then
  --     finish = sub(finish,2)
  -- end 
  local sql = format("select cpy_id,%s,zf,zs from cc_stock_info where addtime in ('%s','%s') and cpy_id <> '' order by cpy_id,addtime   limit %d ;",_type,begin,finish,stock_count);
  
  local md5_key = ngx.md5('sql:'..sql)
  redis:select(0)
  local ok, err = redis:get(md5_key)
  if ok then 
    ngx.say(ok)
    return true
  end 
  local _current_time = ngx.time()
  local _current_table = os.date("*t",_current_time)
  --local db_path = format('/usr/local/openresty/nginx/lua/%02d%02d.db',4,19)
  local db_path = format('/data/wwwroot/sysctrl/db/%02d%02d.db',_current_table['month'],_current_table['day'])
  local db = require("lsqlite3").open(db_path)
  if not db then 
     ngx.say('{}','db failed',db_path)
    return true
  end
  local _temp = stock_cache:get('cpy_name')

  if not _temp then 
    return true
  end
  local cpy_name = json.decode(_temp)
  local _t = {}
  local _tb = {}
  local _count = 1
  local i = 1
  local vv = ''
  
  for k in db:nrows(sql) do

    if vv ~= k['cpy_id']  then
      local _v = k 
      _v['one'] = '0.00'
      _v['name'] = cpy_name[_v['cpy_id']] or ''
      tb_insert(_t,_v)
      _count = _count + 1
   else
      local last  = _count -1
     _t[last]['one'] = format("%.2f",tonumber(k[_type]) - tonumber(_t[last][_type]))
     _t[last]['zs'] = format('%.2f',tonumber(k['zs'] or 0.00) - tonumber(_t[last]['zs'] or 0.00) )
     _t[last]['zf'] = format('%.2f',tonumber(k['zf']) - tonumber(_t[last]['zf']))
   end
   vv =  k['cpy_id']
  end
  local res = json.encode(_t)
  ngx.say(res)
  ngx.eof()
  db:close()
  db = nil
  redis:set(md5_key,res)
  redis:expire(md5_key,_current_time+3600*3)
end)
r:match('GET','/groups',function(params)
  redis:select(2)
  local res = redis:mget('publicGroup','vipGroup')
  local groups =  {
    publicGroup = json.decode(res[1]),
    vipGroup = (type(res[2]) == 'userdata') and {} or json.decode(res[2])
  }
 
  ngx.say(json.encode(groups))
end)
r:match('GET','/vip',function(params)
  local menu = get_Menu()
  redis:select(0)
  local cache = redis:get('last_news')
  menu.news = json.decode(cache)
  menu.leftNav = false
  local view = template.new('view/news.html')
   view:render(menu)
end)
r:match('GET','/666',function(params)
  redis:select(1)
  ngx.say(redis:get('orderInfo'))
  ngx.say(redis:get('ip'))
end)
ngx.status = ngx.HTTP_OK

local function main()
  local ok, errmsg = r:execute(
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


