FROM nginx:stable-alpine

RUN rm /etc/nginx/conf.d/default.conf
COPY ./compose/production/nginx/rance-blog.conf /etc/nginx/conf.d/
