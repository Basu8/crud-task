# MEAN CRUD DevOps Task

This repository contains a full-stack CRUD application built with the **MEAN stack** (MongoDB, Express, Angular 15, Node.js) and a complete DevOps setup:

- Application containerized with Docker
- Deployed on an Ubuntu VM using Docker Compose
- MongoDB running as a container
- Nginx configured as a reverse proxy (port 80)
- CI/CD pipeline implemented using GitHub Actions
- Docker images stored on Docker Hub

The application manages a collection of tutorials with fields:

- `id`
- `title`
- `description`
- `published` (boolean)

Users can create, view, update, delete, and search tutorials by title.

---

## 1. Project Structure

```bash
.
├── backend/
│   ├── Dockerfile
│   ├── package.json
│   ├── server.js
│   └── app/
│       ├── config/
│       │   └── db.config.js
│       ├── controllers/
│       ├── models/
│       └── routes/
├── frontend/
│   ├── Dockerfile
│   ├── package.json
│   ├── angular.json
│   └── src/
│       ├── app/
│       │   ├── components/
│       │   └── services/
│       │       └── tutorial.service.ts
│       └── assets/
├── docker-compose.yml
└── .github/
    └── workflows/
        └── ci-cd.yml
```

---

## 2. Local Development (Without Docker)

### 2.1 Backend (Node.js + Express)

```bash
cd backend
npm install
```

Update MongoDB configuration in:

```bash
backend/app/config/db.config.js
```

Run the server:

```bash
node server.js
```

The backend will start on port **8080** by default.

---

### 2.2 Frontend (Angular)

```bash
cd frontend
npm install
ng serve --port 8081
```

Update backend API URL (if needed) in:

```bash
frontend/src/app/services/tutorial.service.ts
```

Open the application in your browser:

```text
http://localhost:8081/
```

---

## 3. Dockerization

This project is fully containerized using Docker. Dockerfiles exist in both the `backend` and `frontend` directories.

### 3.1 Backend Dockerfile (`backend/Dockerfile`)

```dockerfile
FROM node:18-alpine

WORKDIR /usr/src/app

COPY package*.json ./
RUN npm install --omit=dev

COPY . .

ENV PORT=8080
EXPOSE 8080

CMD ["node", "server.js"]
```

### 3.2 Frontend Dockerfile (`frontend/Dockerfile`)

```dockerfile
# Build stage
FROM node:18-alpine AS build

WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build -- --configuration=production

# Serve with nginx
FROM nginx:alpine

COPY --from=build /app/dist/angular-15-crud /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

---

## 4. Docker Images & Docker Hub

The CI/CD pipeline (or you manually) builds and pushes the following images to Docker Hub:

- `<YOUR_DOCKERHUB_USERNAME>/crud-dd-backend:latest`
- `<YOUR_DOCKERHUB_USERNAME>/crud-dd-frontend:latest`

Build and push manually (optional):

```bash
# Backend
cd backend
docker build -t <YOUR_DOCKERHUB_USERNAME>/crud-dd-backend:latest .
docker push <YOUR_DOCKERHUB_USERNAME>/crud-dd-backend:latest

# Frontend
cd frontend
docker build -t <YOUR_DOCKERHUB_USERNAME>/crud-dd-frontend:latest .
docker push <YOUR_DOCKERHUB_USERNAME>/crud-dd-frontend:latest
```

> Replace `<YOUR_DOCKERHUB_USERNAME>` with your actual Docker Hub username.

---

## 5. AWS VM (Ubuntu) Setup

### 5.1 Create Ubuntu VM

- Cloud provider: e.g. **AWS EC2**
- OS: Ubuntu 22.04 LTS
- Instance type: `t2.micro` or similar
- Security Group inbound rules:
  - **SSH** – TCP 22 from your IP
  - **HTTP** – TCP 80 from `0.0.0.0/0`
  - (Optional for debugging) TCP 8080 from `0.0.0.0/0`

### 5.2 Connect to VM

```bash
ssh -i ~/.ssh/<your-key>.pem ubuntu@<EC2_PUBLIC_IP>
```

### 5.3 Install Docker & Docker Compose

```bash
sudo apt update
sudo apt install -y ca-certificates curl gnupg

sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo   "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg]   https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" |   sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo usermod -aG docker ubuntu
```

Create deployment directory:

```bash
mkdir -p ~/deploy
cd ~/deploy
```

---

## 6. Docker Compose Deployment (On VM)

A `docker-compose.yml` file is used on the VM to deploy MongoDB, backend, and frontend:

```yaml
services:
  mongo:
    image: mongo:6.0
    restart: unless-stopped
    volumes:
      - mongo-data:/data/db
    networks:
      - appnet

  backend:
    image: <YOUR_DOCKERHUB_USERNAME>/crud-dd-backend:latest
    environment:
      - MONGO_URL=mongodb://mongo:27017/dd_db
      - PORT=8080
    depends_on:
      - mongo
    restart: unless-stopped
    networks:
      - appnet

  frontend:
    image: <YOUR_DOCKERHUB_USERNAME>/crud-dd-frontend:latest
    ports:
      - "8080:80"
    depends_on:
      - backend
    restart: unless-stopped
    networks:
      - appnet

volumes:
  mongo-data:

networks:
  appnet:
    driver: bridge
```

On the VM:

```bash
cd ~/deploy
sudo docker compose pull
sudo docker compose up -d --remove-orphans
sudo docker compose ps
```

---

## 7. Nginx Reverse Proxy (Port 80)

Nginx runs on the VM and proxies HTTP traffic on **port 80** to the frontend service on port **8080**.

### 7.1 Install Nginx

```bash
sudo apt update
sudo apt install -y nginx
```

### 7.2 Nginx Site Configuration

Create config:

```bash
sudo nano /etc/nginx/sites-available/crud-mean.conf
```

Add:

```nginx
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:8080/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

Enable site and disable default:

```bash
sudo ln -s /etc/nginx/sites-available/crud-mean.conf /etc/nginx/sites-enabled/crud-mean.conf
sudo rm /etc/nginx/sites-enabled/default

sudo nginx -t
sudo systemctl restart nginx
```

Now the application is accessible at:

```text
http://<EC2_PUBLIC_IP>
```

---

## 8. CI/CD Pipeline (GitHub Actions)

A GitHub Actions workflow automates:

1. Building Docker images for frontend and backend
2. Pushing images to Docker Hub
3. Deploying the updated images to the Ubuntu VM (via SSH)

The workflow file is located at:

```bash
.github/workflows/ci-cd.yml
```

### 8.1 Workflow Definition

```yaml
name: CI/CD - Build & Deploy

on:
  push:
    branches:
      - main

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up QEMU
        uses: docker/setup-qemu-action@v2

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to Docker Hub
        uses: docker/login-action@v2
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}

      - name: Build and push backend image
        uses: docker/build-push-action@v5
        with:
          context: ./backend
          file: ./backend/Dockerfile
          push: true
          tags: ${{ secrets.DOCKERHUB_USERNAME }}/crud-dd-backend:latest

      - name: Build and push frontend image
        uses: docker/build-push-action@v5
        with:
          context: ./frontend
          file: ./frontend/Dockerfile
          push: true
          tags: ${{ secrets.DOCKERHUB_USERNAME }}/crud-dd-frontend:latest

  deploy:
    needs: build-and-push
    runs-on: ubuntu-latest
    steps:
      - name: SSH into VM and deploy
        uses: appleboy/ssh-action@v0.1.8
        with:
          host: ${{ secrets.SSH_HOST }}
          username: ${{ secrets.SSH_USER }}
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          port: ${{ secrets.SSH_PORT }}
          script: |
            mkdir -p ~/deploy
            cd ~/deploy
            sudo docker compose pull
            sudo docker compose up -d --remove-orphans
            sudo docker compose ps
```

### 8.2 GitHub Secrets

Configure the following secrets in your GitHub repository:

- `DOCKERHUB_USERNAME` – Docker Hub username  
- `DOCKERHUB_TOKEN` – Docker Hub access token  
- `SSH_HOST` – Public IP of the VM  
- `SSH_USER` – SSH username (e.g. `ubuntu`)  
- `SSH_PORT` – SSH port (default `22`)  
- `SSH_PRIVATE_KEY` – Contents of the SSH private key (`.pem`)  

---

## 9. Screenshots to Include (for the Task)

You should include screenshots (in a `/screenshots` folder or in the task submission) for:

- **CI/CD configuration and execution**  
  - GitHub Actions workflow run showing successful build & deploy
- **Docker image build and push process**  
  - Logs or Docker Hub page showing backend and frontend images
- **Application deployment and working UI**  
  - Browser screenshot of the CRUD app at `http://<EC2_PUBLIC_IP>`
- **Nginx setup and infrastructure details**  
  - Nginx config file (`crud-mean.conf`)
  - Optional: simple architecture diagram

---

## 10. Application Access

Once deployed and running, the application is accessible at:

```
http://<EC2_PUBLIC_IP>
```

Port 80 is handled by Nginx, which reverse-proxies traffic to the frontend container running on port 8080 on the VM.

Users can then perform full CRUD operations on tutorials and search by title via the web UI.
