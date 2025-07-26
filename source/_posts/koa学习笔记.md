---
title: koa学习笔记
date: 2025-07-26 14:31:57
categories: 前端
tags: nodejs
cover: http://sona-nyl.oss-cn-hangzhou.aliyuncs.com/img/4.jpg
---
## 基本使用
```
const koa = require("koa");
const app = new koa(); 
app.use(async (ctx,next)=>{
    console.log(1)
    await next()
    console.log(2)
    ctx.body="666"
}) //注册中间件
app.use((ctx)=>{
    console.log(3)
})
app.listen(3000) 启动http服务器并监听端口
```
可以看到koa实例提供了两个方法，use注册中间件，listen启动服务器，其中use方法需要传入一个异步的回调函数处理请求，需要以ctx为参数，next为下一个中间件的方法。而且由输出可以观察到中间件的执行顺序是由注册顺序决定的。了解了基本用法后我们再深入。

## 深入

### constructor
进入依赖包的koa/lib/application.js文件，可以看到koa的的构造函数
```
  constructor (options) {
    ...
    this.middleware = [] //中间件数组
    ...
  }
```
在实例化app时初始化中间件数组为空
### use
```
  use (fn) {
    if (typeof fn !== 'function') throw new TypeError('middleware must be a function!')
    debug('use %s', fn._name || fn.name || '-')
    this.middleware.push(fn)
    return this
  }
```
在调用use方法时只做了一个事情，将函数push进中间件数组
### listen 
listen这里干了两件事
1.现在有了中间件数组,得需要有一个方法将它们串联起来，并将串联好的函数作为回调函数传给node的http模块，并启动模块运行。
2.node的http模块需要接收res,req为参数，而use里注册的中间件是以ctx为参数。所以需要把对ctx的操作关联到res和req

### listen-1 *
串联中间件的函数
```
function compose (middleware) { //接受中间件数组
  ...
  return function (context, next) { //返回回调函数
    // last called middleware #
    let index = -1
    return dispatch(0)
    function dispatch (i) {
      if (i <= index) return Promise.reject(new Error('next() called multiple times')) //每个next只能一次调用
      index = i
      let fn = middleware[i]
      if (i === middleware.length) fn = next //如果参数中有回调函数则放入最里层
      if (!fn) return Promise.resolve() //i>
      try {
        return Promise.resolve(fn(context, dispatch.bind(null, i + 1))); //这里的bind方法相当于()=>dispatch(i+1)
      } catch (err) {
        return Promise.reject(err)
      }
    }
  }
  ...
}
```
这里不执行函数，是将 [fn1,fn2,fn3] 的数组转化成 fn1(fn2(fn3())) 的嵌套关系。举个具体点的栗子:
由 [ fn1(语句1;await next()语句2；), fn2(语句3；) ] 
变成 Promise.resolve(语句1;await Promise.resolve(语句3;);语句2;)

我们可以观察到函数的返回是一个promise的无限套娃，这边假设除了函数内除了next全是同步代码，讨论一下其运行顺序。

从 middleware[0] 进入执行 next 前的同步代码，运行到next时由于await和promise.resolve都是立即执行的，所以进入middleware[1] 依此类推 直到最后一个中间件的同步代码全部执行完成然后将middleware[-1]中await 后的代码块压入微队列，然后回溯到middleware[-2]依此类推知道整个函数同步代码执行完成，再从微队列把await 后的代码块依次执行。所以use方法注册的中间件推荐是异步函数，不然在回溯到middleware[0]的过程中遇到同步的任务会提前执行而不加入微队列。

### listen-2
将res和req挂载到ctx
```
  createContext (req, res) {
    /** @type {Context} */
    const context = Object.create(this.context) //根据模板创建对象
    /** @type {KoaRequest} */
    const request = context.request = Object.create(this.request)
    /** @type {KoaResponse} */
    const response = context.response = Object.create(this.response)
    context.app = request.app = response.app = this
    context.req = request.req = response.req = req
    context.res = request.res = response.res = res
    ...
    return context
  }
```
这里把req和res的地址挂载到context.res和context.req并返回context对象，可以通过操作context操作res,req

### listen-3
其他细节内容就不多介绍了，可以自行下载koa3框架查看。~~其实还没想好怎么说~~

## 尾声
累了，去睡觉了。