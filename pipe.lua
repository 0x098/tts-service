
local posix = require("posix")

function popen3(path, ...)
	local stdin_r, stdin_w = posix.pipe()
	local stdout_r, stdout_w = posix.pipe()
	local stderr_r, stderr_w = posix.pipe()

	assert((stdin_w ~= nil and stdout_r ~= nil and stderr_r ~= nil), "pipe() failed")

	local pid, err = posix.fork()
	assert(pid ~= nil, "fork() failed")
	if pid == 0 then
		posix.close(stdin_w)
		posix.close(stdout_r)
		posix.close(stderr_r)

		posix.dup2(stdin_r, posix.fileno(io.stdin))
		posix.dup2(stdout_w, posix.fileno(io.stdout))
		posix.dup2(stderr_w, posix.fileno(io.stderr))

		local ret, err = posix.execp(path, ...)
		assert(ret ~= nil, "execp() failed")

		posix._exit(1)
		return
	end

	posix.close(stdin_r)
	posix.close(stdout_w)
	posix.close(stderr_w)

	return pid, stdin_w, stdout_r, stderr_r
end


function popen3p(pipes,path, ...)
	
	--if not pipes.stdin_r then
	--	pipes.stdin_r,  pipes.stdin_w   = posix.pipe()
	--end
	--if not pipes.stdout_w then
	--	pipes.stdout_r, pipes.stdout_w = posix.pipe()
	--end
	--if not pipes.stderr_w then
	--	pipes.stderr_r, pipes.stderr_w = posix.pipe()
	--end
	assert(pipes.stdin_r)
	assert(pipes.stdout_w)
	assert(pipes.stderr_w)
	
	local stdin_r, stdin_w   = pipes.stdin_r,  pipes.stdin_w   
	local stdout_r, stdout_w = pipes.stdout_r, pipes.stdout_w 
	local stderr_r, stderr_w = pipes.stderr_r, pipes.stderr_w 

	local pid, err = posix.fork()
	assert(pid ~= nil, "fork() failed")
	if pid == 0 then
	
		if stdin_w  then posix.close(stdin_w)  end
		if stdout_r then posix.close(stdout_r) end
		if stderr_r then posix.close(stderr_r) end

		posix.dup2(stdin_r, posix.fileno(io.stdin))
		posix.dup2(stdout_w, posix.fileno(io.stdout))
		posix.dup2(stderr_w, posix.fileno(io.stderr))

		local ret, err = posix.execp(path, ...)
		assert(ret ~= nil, "execp() failed")

		posix._exit(1)
		return
	end

	if pipes.stdin_r  then posix.close(pipes.stdin_r ) end
	if pipes.stdout_w then posix.close(pipes.stdout_w) end
	if pipes.stderr_w then posix.close(pipes.stderr_w) end
	
	return pid, stdin_w, stdout_r, stderr_r
end
