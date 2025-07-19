---
title: CI/CD实践
date: 2025-05-16 13:58:41
tags: github actions
categories: 运维
cover : https://cdn.jsdelivr.net/gh/qqx12345/resource/img/2.webp
---
## 前言
两个月前，当我还拿着刚买的服务器手动部署环境时，每一次部署和更新都要手打Linux命令，属实是非常麻烦。而且如果要给服务器加上其他服务，在没有GUI的Linux也不方便管理和维护，这对只有一台服务器的我都是无法接受的。在了解到docker的容器化思想和CI/CD的流程以后，我决定修改一下服务器的结构。

## 服务器更新
以前我部署服务都需要安装全局环境，但如果在服务器需要频繁更新环境时，这个做法耗时耗力，而且不方便管理，容易造成不必要的资源浪费。而docker就适合解决这些问题--解决环境之间迁移困难和统一部署封装。于是我把每个需要运行的服务打包成一个docker image镜像，然后对每个服务的仓库设置对应的 github 工作流监听每次仓库的 push 然后完成工作脚本，实现对docker镜像和容器的自动搭建。
<br>
![服务器架构图](https://cdn.jsdelivr.net/gh/qqx12345/resource/img/server.webp)

## 实现流程

### 配置docker环境
可以查看示例：[阿里云文档](https://developer.aliyun.com/article/1457025)
### dockerflie
由于每个服务的依赖不同，需要自定义构建镜像，大概就是把你服务需要的环境镜像copy过来，然后再写上需要运行的shell脚本就行
示例：
``` dockerfile
FROM node:20-alpine AS builder
WORKDIR /blog
COPY . .
RUN npm install -g hexo-cli && npm install && hexo clean && hexo generate
FROM nginx:alpine
COPY --from=builder /blog/public /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```
### github工作流
当我们在项目根目录里创建了一个./github/workflow/XX.yaml时，github会识别这个文件，并单开一个服务器并在触发事件时执行该文件定义的任务。这就是actions干的事情，其中的actions服务器系统和运行的脚本都可以自定义，而且能在github上直接查看运行日志，但是运行时间不能超过6小时(一般也用不到就是)。为了实现自动部署，我要在actions的服务器上远程登陆我的实际服务器并实现构建镜像的操作，而不暴露服务器信息，这里可以设置settings里的Actions secrets and variables设置保密信息。
于是就有了这样一个工作流示例：
``` xx.yml
name: GitHub Actions Demo
run-name: ${{ github.actor }} is testing out GitHub Actions 🚀
on: [push]
jobs:
  Explore-GitHub-Actions:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      - name: Build and run Go program
        uses: appleboy/ssh-action@master
        with:
          host: ${{ secrets.HOST_IP }}	# 服务器地址
          username: ${{ secrets.USRNAME }} # 登陆用户名
          key: ${{ secrets.KEY }} # 服务器私钥
          port: 22
          script: |
            cd /usr/local/blog
            git checkout . && git pull || { echo "❌ 拉取代码失败"; exit 1; }
            docker ps -a --format '{{.Names}}' | grep -w myblog && docker stop myblog && docker rm myblog || echo "ℹ️ 容器 myblog 不存在，跳过"
            docker build -t myapp:v1 . || { echo "❌ 构建失败"; exit 1; }
            docker images | grep myapp || { echo "❌ 镜像不存在"; exit 1; }
            docker run -d -p 8080:80 --name myblog myapp:v1 || { echo "❌ 运行失败"; exit 1; }
            echo "✅ 部署完成"
```
这里我使用了一个开源的工作流模板去使用ssh连接服务器，然后在script里写了拉取代码，停止容器，构建镜像，运行容器的操作。也可以使用其他方式连接服务器，比如使用docker的api，但是我觉得这种方式比较简单，而且可以在github上查看运行日志，方便调试。
### 结语
github actions的工作流可以实现很多功能，比如自动部署，自动测试，自动发布等等。但是也有一些缺点，比如不能在actions里运行一些需要root权限的操作，比如安装一些全局环境，而且不能在actions里运行一些需要用户输入的操作，比如安装一些全局环境。所以在使用github actions时，需要注意一些问题，避免出现一些不必要的错误。