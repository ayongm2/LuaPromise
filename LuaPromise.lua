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
		:andThen(function ( data )
	    	print("do something to change data")
	    	data = "hello world..."
	        return true, data
	    end)
	    :andThen(function ( data )
	        print("do something~~~", data)
	    end)
	    :catch(function ( msg )
	        print("catched:", msg)
	    end)
	    :finally(function (  )
	        print("finally: Over~~~~~~") 
	    end)
	    :done()

	===多个Promise顺序调用的情况===
	httpGetPromise("www.google.com")
		:andThen(function ( data )
	    	print("do something to change data")
	    	data = "hello world..."
	        return true, data
	    end)
	    :andThen(function(data)
	    	return true, httpGetPromise("www.bing.com")
	    end)
	    :andThen(function ( data )
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

LuaPromise = {}
local mt = {__index = LuaPromise}
function LuaPromise.new( process )
	local promise = setmetatable({}, mt)
	promise.chain_ = {{main_process = process}}
	return promise
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

local function isPromise_( p )
	if type(p) == "table" then
		return getmetatable(p) == mt
	else
		return false
	end
end

-- 设定结束,开始处理
function LuaPromise:done()
	assert(self.chain_, "The LuaPromise instance was finished. Can't run again")
	self.coroutine_ = coroutine_create(function (  )
		local ok, data, index = true
		local promiseInfo = table.remove(self.chain_, 1)
		-- 先执行第一个,也就是Promise本身
		promiseInfo.main_process(self)
		-- 等待返回后继续处理吧
		ok, data = coroutine_yield()
		local total = #self.chain_
		-- 剩下andThen之类顺序处理
		for i, promiseInfo in ipairs(self.chain_) do
			-- 看看返回的是不是Promise,是的话当前Promise就可以结束了,执行交给新Promise
			if isPromise_(data) then
				-- 转移下剩下的要执行的步骤
				for j = i, #self.chain_ do
					data.chain_[#data.chain_ + 1] = self.chain_[j]
				end
				data:done()
				-- 把当前的结束了
				self.chain_ = nil
				break
			end
			-- 执行主体
			ok, data = promiseInfo.main_process(data)
			-- 看是结束了还是挂起
			if ok == nil and data == nil then 
				if i == total then 
					ok = true
				else
					ok, data = coroutine_yield()
				end
			end
			-- 中断的结束判定
			if not ok then 
				index = i
				break 
			end
		end
		if self.chain_ then 
			-- 收尾下
			callFinally_(self.chain_, index, not ok, data)
			self.chain_ = nil
		end
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













