# LuaPromise
```txt
Promise, 把回调写法转换为顺序写法的一种方式,具体可参看js里的promise, 主要参考q
这里只是用lua的coroutine写的一个简单的基本的实现
使用一次后即作废,三种使用方式请参看下面的例子
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
            -- 第一种使用方式,不使用协程直接顺序执行
            print("do something to change data")
            data = "hello world..."
            return true, data
        end)
        :andThen(function ( data, promise )
            -- 进行延迟执行,这里使用quick-x中的延迟机制
            -- 第二种使用方式,使用当前promise对象通过协程继续流程
            scheduler.performWithDelayGlobal(function ( ... )
                promise:resolve(data)
            end, 1.0)
        end)
        :andThen(function(data)
            -- 第三种使用方式,使用新的promise进行新的处理,复用已有promise时比较方便
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
```

