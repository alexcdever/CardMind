# 使用 nginx 作为基础镜像
FROM nginx:alpine

# 设置工作目录
WORKDIR /usr/share/nginx/html

# 复制本地构建产物
COPY dist/ .

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
