#!/bin/bash
set -e

echo "=== Updating system ==="
sudo yum update -y

echo "=== Installing system packages ==="
sudo yum install -y python3 python3-pip python3-venv git nginx

echo "=== Creating project directory ==="
sudo mkdir -p /var/www/room_booking
sudo chown ec2-user:ec2-user /var/www/room_booking
cd /var/www/room_booking

echo "=== Creating Python virtual environment ==="
python3 -m venv venv
source venv/bin/activate

echo "=== Installing Python dependencies ==="
pip install --upgrade pip
pip install django mysqlclient gunicorn stripe paypalcheckoutsdk

echo "=== Cloning your GitHub project ==="
# Replace YOURNAME with your GitHub username
git clone https://github.com/YOURNAME/room_booking.git .

echo "=== Applying Django migrations ==="
python manage.py migrate

echo "=== Collecting static files ==="
python manage.py collectstatic --noinput

echo "=== Creating Gunicorn systemd service ==="
sudo tee /etc/systemd/system/room_booking.service > /dev/null <<EOF
[Unit]
Description=Gunicorn service for room_booking Django project
After=network.target

[Service]
User=ec2-user
Group=ec2-user
WorkingDirectory=/var/www/room_booking
Environment="PATH=/var/www/room_booking/venv/bin"
ExecStart=/var/www/room_booking/venv/bin/gunicorn --workers 3 --bind unix:/var/www/room_booking/room_booking.sock room_booking.wsgi:application

[Install]
WantedBy=multi-user.target
EOF

echo "=== Starting Gunicorn ==="
sudo systemctl daemon-reload
sudo systemctl enable room_booking
sudo systemctl start room_booking

echo "=== Configuring Nginx ==="
sudo tee /etc/nginx/conf.d/room_booking.conf > /dev/null <<EOF
server {
    listen 80;
    server_name _;

    location /static/ {
        alias /var/www/room_booking/static/;
    }

    location / {
        proxy_pass http://unix:/var/www/room_booking/room_booking.sock;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

echo "=== Restarting Nginx ==="
sudo systemctl enable nginx
sudo systemctl restart nginx

echo "=== Adjusting firewall (Security Groups recommended) ==="
sudo systemctl start firewalld || true
sudo firewall-cmd --permanent --add-service=http || true
sudo firewall-cmd --permanent --add-service=https || true
sudo firewall-cmd --reload || true

echo "=== Setup complete ==="
echo "Visit your EC2 public IP to verify Django is running."

