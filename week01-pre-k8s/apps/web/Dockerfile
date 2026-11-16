FROM node:22-alpine AS build
WORKDIR /app
COPY package.json ./package.json
RUN npm install 
COPY . .
RUN npm run build  


FROM nginxinc/nginx-unprivileged:alpine3.22 AS runner
COPY --chown=nginx:root --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
USER nginx
EXPOSE 8080

