# VPN + Nginx Docker Setup

This project provides a ready-to-run **Docker Compose stack** with:

- **OpenVPN** on port **443** for secure VPN access and location masking
- **Nginx** on port **80** as a reverse proxy, with support for multiple subdomains
- **Admin username/password authentication** for VPN

## 📦 Project Structure

```
vpn-nginx/
│── docker-compose.yml      # Compose file for OpenVPN + Nginx
│── setup.sh                # Setup script (auto initializes everything)
│── clean.sh                # Cleanup script
│── nginx/
│    ├── conf.d/            # Nginx vhost configs (add more subdomains here)
│    │    └── default.conf
│    └── html/              # Static HTML root for default site
│         └── index.html
│── openvpn/                # OpenVPN configs (auto-generated)
│── vpn-users/              # Admin/user credentials for OpenVPN
```

## 🚀 Setup Instructions

1. **Unzip the project** and enter the folder:

```bash
unzip vpn-nginx.zip
cd vpn-nginx
```

2. **Make the setup script executable**:

```bash
chmod +x setup.sh
```

3. **Run setup** (this initializes OpenVPN, generates certificates, creates admin credentials, and starts services):

```bash
./setup.sh
```

4. After setup, you will get a client configuration file:

```
myclient.ovpn
```

Import this into your **OpenVPN Connect** client.

---

## 🔑 VPN Authentication

This setup uses **two layers of authentication**:

1. **Certificates** (generated during `setup.sh`)
2. **Username/Password** (stored in `vpn-users/credentials`)

After running `setup.sh`, you’ll see something like:

```
🔑 Admin VPN credentials created:
   Username: admin
   Password: 3fa92d7e1c5a4f6d
```

- These credentials are required in **OpenVPN Connect** when importing `myclient.ovpn`.  
- To add more users, edit `vpn-users/credentials` and append new lines:

```
user1:password123
user2:secret456
```

Then restart the OpenVPN container:

```bash
docker compose restart openvpn
```

---

## 🌍 Nginx Reverse Proxy

- Default config is in `nginx/conf.d/default.conf`
- To add more subdomains, create new `.conf` files inside `nginx/conf.d/`
- Example for `api.example.com` → local service on port 8080:

```nginx
server {
    listen 80;
    server_name api.example.com;

    location / {
        proxy_pass http://host.docker.internal:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

Reload Nginx by restarting the container:

```bash
docker compose restart nginx
```

---

## 🧹 Cleanup

To remove all containers, configs, and generated files:

```bash
chmod +x clean.sh
./clean.sh
```

This will:

- Stop and remove Docker containers (OpenVPN + Nginx)
- Remove OpenVPN configs and certificates
- Remove Nginx configs and HTML
- Remove client `.ovpn` profiles

---

## ✅ Verification

- Visit `http://YOUR_SERVER_IP` → You should see the Nginx welcome page.
- Connect with OpenVPN → Your public IP should now match the server’s IP.
- Use admin username/password for VPN login.
