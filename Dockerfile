FROM registry.aliyuncs.com/library/node:20-alpine AS builder
WORKDIR /blog

COPY . .

RUN npm install -g hexo-cli && npm install && hexo clean && hexo generate

FROM registry.aliyuncs.com/library/nginx:alpine

COPY --from=builder /blog/public /usr/share/nginx/html

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY sona-nyl.cn.pem /etc/nginx/ssl/sona-nyl.cn.pem
COPY sona-nyl.cn.key /etc/nginx/ssl/sona-nyl.cn.key

EXPOSE 80
EXPOSE 443

CMD ["nginx", "-g", "daemon off;"]