# Step 1: Create a custom service account
resource "google_service_account" "n8n_service_account" {
  account_id   = "n8n-sa"
  display_name = "n8n Service Account"
}

# Assign roles to the service account (add more roles as needed)
resource "google_project_iam_member" "n8n_sa_iam" {
  project = var.project_id
  role    = "roles/compute.instanceAdmin.v1"
  member  = "serviceAccount:${google_service_account.n8n_service_account.email}"
}

# Step 2: Reserve a static IP
resource "google_compute_address" "n8n_static_ip" {
  name   = "n8n-static-ip"
  region = var.region
}

# Step 3: Create a persistent disk
# Define a resource policy for daily snapshots
resource "google_compute_resource_policy" "n8n_snapshot_policy" {
  name   = "n8n-daily-snapshot-policy"
  region = var.region

  snapshot_schedule_policy {
    schedule {
      daily_schedule {
        days_in_cycle = 1       # Snapshot daily
        start_time    = "04:00" # Time in UTC, adjust as necessary
      }
    }

    retention_policy {
      max_retention_days    = 7 # Retain snapshots for 7 days, adjust as necessary
      on_source_disk_delete = "KEEP_AUTO_SNAPSHOTS"
    }

    snapshot_properties {
      labels = {
        "created-by" = "terraform"
      }
    }
  }
}

# Create the persistent disk
resource "google_compute_disk" "n8n_persistent_disk" {
  name = "n8n-data-disk"
  type = "pd-standard" # or "pd-ssd"
  zone = var.zone

  size = 2000 # Size in GB

}
# Attach the snapshot policy to the disk
resource "google_compute_disk_resource_policy_attachment" "n8n_persistent_disk_attachment" {
  name = google_compute_resource_policy.n8n_snapshot_policy.name
  disk = google_compute_disk.n8n_persistent_disk.name
  zone = var.zone
}

# Step 4: Create the GCE instance with the persistent disk
resource "google_compute_instance" "n8n_instance" {
  name         = "n8n-server"
  machine_type = "e2-standard-4"
  zone         = var.zone

  # Boot disk settings
  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2004-lts"
      size  = 50 # 50GB boot disk
    }
  }

  # Network interface to allow external access
  network_interface {
    network    = "default"
    subnetwork = "default"

    # Assign the reserved static IP to this instance
    access_config {
      nat_ip = google_compute_address.n8n_static_ip.address
    }
  }

  # Attach the persistent disk
  attached_disk {
    source = google_compute_disk.n8n_persistent_disk.id
    mode   = "READ_WRITE"
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_ed25519.pub")}" # Add your public key here
  }

  # Config files
  provisioner "remote-exec" {
    inline = [
      "sudo mkdir /etc/startup",
      "sudo chmod a+w /etc/startup",
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/id_ed25519")
      host        = self.network_interface[0].access_config[0].nat_ip
    }
  }
  provisioner "file" {
    source      = "support/docker-compose.yml"
    destination = "/etc/startup/docker-compose.yml"
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/id_ed25519")
      host        = self.network_interface[0].access_config[0].nat_ip
    }
  }

  provisioner "file" {
    source      = "support/.env"
    destination = "/etc/startup/.env"
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/id_ed25519")
      host        = self.network_interface[0].access_config[0].nat_ip
    }
  }

  provisioner "file" {
    source      = "support/init-data.sh"
    destination = "/etc/startup/init-data.sh"
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/id_ed25519")
      host        = self.network_interface[0].access_config[0].nat_ip
    }
  }

  # Metadata startup script to install Docker and mount the disk
  metadata_startup_script = <<-EOT
    #! /bin/bash
    sudo apt-get update
    sudo apt-get install -y nginx certbot python3-certbot-nginx docker.io
    sudo systemctl start docker
    sudo systemctl enable docker
    # Add Docker's official GPG key:
    sudo apt-get update
    sudo apt-get install ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    # Add the repository to Apt sources:
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update
    sudo apt-get install docker-compose-plugin

    # Format the persistent disk if necessary
    if ! blkid /dev/sdb; then
      sudo mkfs.ext4 -F /dev/sdb
    fi

    # Mount the disk to 
    sudo mkdir -p /mnt/n8n_persistent_disk
    sudo mount /dev/sdb /mnt/n8n_persistent_disk

    sudo rm -rf /etc/letsencrypt

    sudo ln -s /mnt/n8n_persistent_disk/n8n_storage /etc/n8n_storage
    sudo ln -s /mnt/n8n_persistent_disk/db_storage /etc/db_storage
    sudo ln -s /mnt/n8n_persistent_disk/redis_storage /etc/redis_storage
    sudo ln -s /mnt/n8n_persistent_disk/letsencrypt /etc/letsencrypt
    
    sudo chown -R 1000:1000 /etc/n8n_storage
    sudo chmod a+w /etc/n8n_storage
    sudo chown -R root:root /etc/letsencrypt
    sudo chmod -R 755 /etc/letsencrypt

    # Persist the mount across reboots
    echo '/dev/sdb /etc/n8n ext4 defaults 0 2' | sudo tee -a /etc/fstab

    # Install the Ops Agent for logging and monitoring
    curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
    sudo bash add-google-cloud-ops-agent-repo.sh --also-install

    # Run n8n docker compose infrastructure (Redis, Postgres, n8n, plus worker and webhook worker)
    cd /etc/startup
    sudo docker compose up -d
    
    # Obtain SSL certificate from Let's Encrypt using Certbot
    systemctl stop nginx
    # Check if certificate exists, if not, request it
    if [ ! -f /etc/letsencrypt/live/n8n.storage24.com/fullchain.pem ]; then
      sudo certbot certonly --standalone -d n8n.storage24.com --non-interactive --agree-tos -m admin@storage24.com
    else
      sudo certbot renew --quiet
    fi

    # I ran out of certificates due to many deployments
    # sudo certbot certonly --standalone -d n8n.storage24.com --non-interactive --agree-tos -m admin@storage24.com
    # sudo certbot certonly --staging --standalone -d n8n.storage24.com --non-interactive --agree-tos -m admin@storage24.com
    # Set up Certbot for automatic renewal
    echo "0 0 * * * /usr/bin/certbot renew --quiet" | sudo tee -a /etc/crontab > /dev/null

    # Nginx reverse proxy configuration
    cat <<EOF > /etc/nginx/sites-available/n8n
        server {
            listen 80;
            server_name n8n.storage24.com;

            # Redirect HTTP to HTTPS
            return 301 https://$server_name$request_uri;
        }

        server {
            listen 443 ssl;
            server_name n8n.storage24.com;

            # SSL certificate files (letsencrypt as an example)
            ssl_certificate /etc/letsencrypt/live/n8n.storage24.com/fullchain.pem;
            ssl_certificate_key /etc/letsencrypt/live/n8n.storage24.com/privkey.pem;

            ssl_protocols TLSv1.2 TLSv1.3;
            ssl_prefer_server_ciphers on;

            location / {
                proxy_pass http://localhost:5678;  # Forward traffic to n8n service
                proxy_set_header Host \$host;
                proxy_set_header X-Real-IP \$remote_addr;
                proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Proto \$scheme;
                # WebSocket headers
                proxy_set_header Upgrade \$http_upgrade;
                proxy_set_header Connection "Upgrade";
                # Increase timeouts to handle long-lived WebSocket connections
                proxy_read_timeout 86400s;
                proxy_send_timeout 86400s;
            }
            # Webhook traffic
            location /webhook/ {
                proxy_pass http://webhook_pool; # Direct to the webhook upstream
                proxy_set_header Host \$host;
                proxy_set_header X-Real-IP \$remote_addr;
                proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Proto \$scheme;

                # WebSocket headers
                proxy_set_header Upgrade \$http_upgrade;
                proxy_set_header Connection "Upgrade";

                # Timeouts for long-lived connections
                proxy_read_timeout 86400s;
                proxy_send_timeout 86400s;
            }
        }
        # Define upstream group for webhook processors
        upstream webhook_pool {
            server localhost:5681; # Webhook processor 1
            server localhost:5682; # Webhook processor 2
            server localhost:5683; # Webhook processor 3
        }
    EOF

    # Enable the Nginx site configuration and reload
    sudo ln -s /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/
    sudo nginx -t && sudo systemctl start nginx

  EOT

  # Tags to allow HTTP/HTTPS traffic
  tags = ["http-server", "https-server"]

  # Assign the custom service account
  service_account {
    email  = google_service_account.n8n_service_account.email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }
}

# Step 5: Firewall rule to allow external HTTP/HTTPS traffic
resource "google_compute_firewall" "default" {
  name    = "allow-http-https"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["http-server", "https-server"]
}
