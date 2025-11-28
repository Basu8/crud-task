# frontend/Dockerfile
# build stage
FROM node:18-alpine AS build

WORKDIR /usr/src/app

COPY package*.json ./
RUN npm install

COPY . .
# ensure Angular CLI present if needed (not required if scripts work)
RUN npm run build -- --configuration=production

# production stage with nginx
FROM nginx:stable-alpine

# remove default nginx content
RUN rm -rf /usr/share/nginx/html/*

# Copy built app from previous stage
COPY --from=build /usr/src/app/dist/angular-15-crud/ /usr/share/nginx/html/

# Copy custom nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
