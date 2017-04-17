local route = require('router')
local format = string.format
local len = string.len
local byte = string.byte
local sub = string.sub
local tb_insert = table.insert
local template = require "resty.template"
template.caching(false)

ngx.req.read_body()
ngx.header.content_type = 'text/html'
local r = route.new()
local stock_cache = ngx.shared.stock_cache

r:match('GET','/',function()
  -- local header = template.compile 'view/base_header.tpl' {}
  
   -- local filename = ngx.var.document_root.."/view/index.html"

   local view = template.new('view/index.html')
   view:render({
      title = "主力动向观测站",
      url = {
        ['list'] = {
          {key = "主力资金净流入",url = "/"},
          {key = "分时DDX(主力强度)",url = "/ddx.html"},
          {key = "逆势主力资金流",url = "nxzl.html"}
        }
      }   
    });
    -- local view = template.new('view/index.html')
    -- view:render()
end);

r:match('GET','/echarts',function()


  local view = template.new('view/echarts.html')
   view:render({
      title = "主力动向观测站",
      url = {
        ['list'] = {
          {key = "主力资金净流入",url = "/"},
          {key = "分时DDX(主力强度)",url = "/ddx.html"},
          {key = "逆势主力资金流",url = "nxzl.html"}
        }
      }   
    });
end)
r:match('GET','/ddx.html',function()
  local view = template.new('view/ddx.html')
   view:render({
      title = "主力动向观测站",
      url = {
        ['list'] = {
          {key = "主力资金净流入",url = "/"},
          {key = "分时DDX(主力强度)",url = "/ddx.html"},
          {key = "逆势主力资金流",url = "nxzl.html"}
        }
      }   
    });
end)
r:match("GET", '/nxzl.html',function()
  local view = template.new('view/nxzl.html')
   view:render({
      title = "主力动向观测站",
      url = {
        ['list'] = {
          {key = "主力资金净流入",url = "/"},
          {key = "分时DDX(主力强度)",url = "/ddx.html"},
          {key = "逆势主力资金流",url = "nxzl.html"}
        }
      }   
    });
end)
r:match('GET','cache',function()
  
  ngx.say(ngx.localtime())
  ngx.say('from memcached.')
end)
r:match('GET','/news',function(params)
    local view = template.new('view/news.html')
    view:render({})
end)
r:match('GET','/echarts_search',function(params)

  local json = require('rapidjson')
  local args = ngx.req.get_uri_args()
  local begin = args['begin'] or '9,15'
  local finish = args['finish'] or '13,00'
  local redis = require("redis_db").new()
  if byte(begin,1,1) == 48 then
      begin = sub(begin,2)
  end
  if byte(finish,1,1) == 48 then
      finish = sub(finish,2)
  end 
  local sql = format("select cpy_id,zlbfb,zf,zs from cc_stock_info where addtime in ('%s','%s') and cpy_id <> '' order by cpy_id,addtime   limit 5914 ;",begin,finish);
  local md5_key = ngx.md5('sql:'..sql)
  redis:select(0)
  local ok, err = redis:get(md5_key)
  if ok then 
    ngx.say(ok)
    ngx.exit(200)
  end 


  local _current_time = ngx.time()
  local _current_table = os.date("*t",_current_time)
  local db_path = format('/usr/local/openresty/nginx/lua/%02d%02d.db',_current_table['month'],_current_table['day'])
  local db = require("lsqlite3").open(db_path)
  if not db then 
    ngx.say('db nil ',db_path) 
    ngx.exit(200)
  end
  local _temp = stock_cache:get('cpy_name')

  if not _temp then 
    return
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
      _v['name'] = cpy_name[_v['cpy_id']]
      tb_insert(_t,_v)
      _count = _count + 1
   else
      local last  = _count -1
     _t[last]['one'] = format("%.2f",tonumber(k['zlbfb']) - tonumber(_t[last]['zlbfb']))
     _t[last]['zs'] = format('%.2f',tonumber(k['zs']) - tonumber(_t[last]['zs']))
     _t[last]['zf'] = format('%.2f',tonumber(k['zf']) - tonumber(_t[last]['zf']))
   end
   vv =  k['cpy_id']
  end
  db:close()
  db = nil
  local res = json.encode(_t)
  ngx.say(res)
  ngx.eof()
  redis:set(md5_key,res)
  redis:expire(md5_key,_current_time+3600*3)
  
end)

function main()
  local ok, errmsg = r:execute(
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

local ok, err = pcall(main)

if not ok then ngx.say(err) end


