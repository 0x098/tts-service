
local posix = require("posix")

local lfs = require("lfs")
local lf = require("luafcgid")

local inspect = require "inspect"
require "waveout"

function PrintTable(...)
	print(inspect{...})
end

local function expire(dat)
	dat.fd:close()
	dat.fd = nil
end

local cache = {}
local function addcache(datas)
	if #cache>15 then
		local dat = cache[1]
		table.remove(cache,1)
		expire(dat)
	end
	
	local t = {}
	for k,v in next,datas do
		t[k] = v
	end
	
	cache[#cache+1] = t
end

local function getcache(datas)
	for id,cachedatas in next,cache do
		local found
		for key,val in next,datas do
			if cachedatas[key] ~= val then
				found = false
				break
			else
				found = true
			end
		end
		if found then
			return id,cachedatas
		end
	end
end

local function trim(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end


local entry_tmp = {}
local function serve_ogg(con,fd)
	assert(fd:seek("set",0))
	
	con:header("Content-Type", "audio/ogg")
	--con:header("content-disposition", "attachment; filename=\"" .. "audio.ogg" .. "\"");

	for i=1,8192 do
		local dat = fd:read(128)
		if not dat then break end
		con:puts(dat)
	end
end





require("os")
require("io")
posix = require("posix")

dofile "pipe.lua"


local socket=require"socket"

local function Now() return socket.gettime() end

local written=0
function main(env, con)
	
	local params = lf.parse(env.QUERY_STRING)
	local txt = params.txt
	assert(txt and type(txt)=='string' and #txt>0 and #txt<10000)

	print(string.format("ASK %q",txt))
	 
	entry_tmp.txt = txt
	entry_tmp.fd = nil

	local id,cached = getcache(entry_tmp)

	if id then
		print("CACHED, SERVING\n")
		local fd = cached.fd
		serve_ogg(con,fd)
		return
	else
		print("cachecnt",#cache)
	end

	local function puts(a)
		con:puts(a)
	end
		
	--print("WRITING TO",fpath)
	local t={
		'--stdin',
		'--stdout',
		'-b', '1',
		'-a', '200',
		'--path', '/home/srcds/espeakd/espeak/share',
		'-m',
	}

	local tt={}
	for k,v in next,t do
		tt[k]=("%q"):format(v)
	end

	local fd = io.tmpfile()
	local fdn = posix.fileno(fd)
	
	local t_1 = Now()
	local lpid, lstdin_fd, lstdout_fd, lstderr_fd = popen3('/home/srcds/espeakd/espeak/bin/espeak-ng',unpack(t))
	
	local nbytes, err = posix.write(lstdin_fd, txt..'\n')
	if nbytes == nil then
		error(err)
	end
	
	posix.close(lstdin_fd)
	
	local pipes={}
		pipes.stdin_r,  pipes.stdin_w  = lstdout_fd,nil
		pipes.stdout_r, pipes.stdout_w = nil,fdn
		pipes.stderr_r, pipes.stderr_w = posix.pipe()
	
	local lpid2, lstdin_fd2, lstdout_fd2, lstderr_fd2 = popen3p(pipes,'/usr/bin/oggenc','-Q','--','-')

	
	--posix.close(lstdout_fd)
	--posix.close(pipes.stdout_w)
	posix.close(pipes.stderr_w)
	
	--local ok
	--local str,err
	--for i=1,1024*2 do
	--	str, err = posix.read(lstdout_fd, 1024)
	--	if str and str~="" then
	--		fd:write(str)
	--	else
	--		ok=true
	--		break
	--	end
	--end
	
	--if not ok then
	--	error(err or "TOOBIG?!?")
	--end
	
	errstr, err = posix.read(lstderr_fd, 1024^2)
	if errstr and #errstr>0 then
		error(errstr)
	end
	
	errstr, err = posix.read(lstderr_fd2, 1024^2)
	if errstr and #errstr>0 then
		error(errstr)
	end
	
	local pid, reason, status = posix.wait(lpid)
	
	if not status then 
		error(reason)
	end
	local pid, reason, status = posix.wait(lpid2)
	
	if not status then 
		error(reason)
	end
	
	entry_tmp.fd = fd
	addcache(entry_tmp)

	
	serve_ogg(con,fd)
	
	local sz = fd:seek("end")

	local t_2 = Now()
	print("Took "..math.ceil(1000*(t_2-t_1))..' ms','size: '.. math.ceil(sz/1024) ..' KB')
	print""
end


local _main = main
main = function(...)
	local ok, err = xpcall(_main,debug.traceback,...)
	if not ok then print(err) end
end