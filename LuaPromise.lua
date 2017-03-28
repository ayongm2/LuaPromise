--[[
Promise, 把回调写法转换为顺序写法的一种方式,具体可参看js里的promise
这里只是用lua的coroutine写的一个简单的基本的实现
e.g.
	function httpGetPromise(url)
		return LuaPromise.new(
			function (promise)
				http.get(
					url,
					function (event, response)
						promise:resolve(response)
					end,
					function (event)
						promise:reject(event.request:getErrorMessage())
					end
				)
			end
		)
	end
	httpGetPromise("www.google.com")
		:andThen(function ( promise, data )
	    	print("do something to change data")
	    	data = "hello world..."
	        return true, data
	    end)
	    :andThen(function ( promise, data )
	        print("do something~~~", data)
	    end)
	    :catch(function ( msg )
	        print("catched:", msg)
	    end)
	    :finally(function (  )
	        print("finally: Over~~~~~~") 
	    end)
	    :done()
--]]

local LuaPromise

local coroutine = coroutine
local coroutine_create = coroutine.create
local coroutine_yield = coroutine.yield
local coroutine_resume = coroutine.resume
local assert = assert
local ipairs = ipairs

if class then 
	-- for quick-x
	LuaPromise = class("LuaPromise")
	function LuaPromise:ctor( process )
		self.chain_ = {{main_process = process}}
	end
else
	LuaPromise = {}
	function LuaPromise.new( process )
		local promise = setmetatable({}, {__index = LuaPromise})
		promise.chain_ = {{main_process = process}}
		return promise
	end
end
-- 处理函数,其process函数里要返回两个数据,成功与否和数据,最后一个处理函数不用返回
function LuaPromise:andThen( process )
	assert(self.chain_, "The LuaPromise instance was finished. Can't run again")
	self.chain_[#self.chain_ + 1] = {main_process = process}
	return self
end
-- 错误处理函数,其是附属与上一个andThen的
function LuaPromise:catch( process )
	assert(self.chain_, "The LuaPromise instance was finished. Can't run again")
	self.chain_[#self.chain_].reject_process = process
	return self
end
-- finally处理函数,其是附属与上一个andThen的
function LuaPromise:finally( process )
	assert(self.chain_, "The LuaPromise instance was finished. Can't run again")
	self.chain_[#self.chain_].finally_process = process
	return self
end

local function callFinally_( chain, index, rejected, data )
	local lastPromiseInfo = chain[#chain]
	local promiseInfo = chain[index or 0]
	-- 判断是中途出错还是做到最后一步了
	local hasPromiseInfo = promiseInfo and promiseInfo ~= lastPromiseInfo 
	if rejected then 
		-- 出错的情况下
		if hasPromiseInfo and promiseInfo.reject_process then 
			-- 中途出错时若有出错处理函数则调用
			promiseInfo.reject_process(data)
		elseif lastPromiseInfo.reject_process then 
			-- 调用最后一个出错处理函数
			lastPromiseInfo.reject_process(data)
		end
	end
	if hasPromiseInfo and promiseInfo.finally_process then 
		-- 中途出错时若有finally处理函数则调用
		promiseInfo.finally_process(data)
	end
	-- 不管出不出错,都调用最后一个finally函数
	if lastPromiseInfo.finally_process then 
		lastPromiseInfo.finally_process(data)
	end
end
-- 设定结束,开始处理
function LuaPromise:done()
	assert(self.chain_, "The LuaPromise instance was finished. Can't run again")
	self.coroutine_ = coroutine_create(function (  )
		local ok, data, index = true
		local total = #self.chain_
		for i, promiseInfo in ipairs(self.chain_) do
			ok, data = promiseInfo.main_process(self, data)
			if ok == nil and data == nil then 
				if i == total then 
					ok = true
				else
					ok, data = coroutine_yield()
				end
			end
			if not ok then 
				index = i
				break 
			end
		end
		callFinally_(self.chain_, index, not ok, data)
		self.chain_ = nil
	end)
	coroutine_resume(self.coroutine_)
	return self
end
-- 成功时调用函数
function LuaPromise:resolve(data)
	coroutine_resume(self.coroutine_, true, data)
end
-- 失败时调用函数
function LuaPromise:reject(data)
	coroutine_resume(self.coroutine_, false, data)
end

return LuaPromise













