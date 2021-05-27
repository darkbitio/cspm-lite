# CSPM-lite


CSPM-lite is a lighter weight version of [https://github.com/OpenCSPM/opencspm](https://github.com/OpenCSPM/opencspm) designed to be run headless and instead "push" all results into a time series database for viewing in Grafana dashboards.

## Architecture

Refer to [https://github.com/OpenCSPM/opencspm-terraform-gcp](https://github.com/OpenCSPM/opencspm-terraform-gcp) for architecture details.  CSPM-lite is identical with the exception of what is installed on the OpenCSPM VM (4th bullet).

Following the instructions for OpenCSPM with the exception of creating the OpenCSPM VM is the key prerequisite step.

## Installation

### Initial infrastructure

After following the steps [https://github.com/OpenCSPM/opencspm-terraform-gcp](https://github.com/OpenCSPM/opencspm-terraform-gcp) to build out the collection infrastructure, the following instructions apply to create the CSPM-lite VM in place of the OpenCSPM VM.

### Create the CSPM-lite VM

First, create a new VM next to the OpenCSPM VM that is identical with the exception of running the latest Ubuntu OS.  Using the `Create Similar` button, change the name to `db-tenant-<tenantid>-cspm-lite-vm` and change the OS to `Ubuntu 20.04 LTS Minimal` with a `80GB` SSD persistent disk. Under the `Metadata` section, delete the `user-data` key/value pair.  Create the instance.

### Connect to the VM

Connect to the VM

```
gcloud beta compute ssh --zone "us-central1-a" "db-tenant-<tenantid>-cspm-lite-vm"  --tunnel-through-iap --project "db-tenant-<tenantid>"
```

Become root

```
sudo su -
cd /root
```

Create an egress firewall rule that allows the VPC to reach `0.0.0.0/0` via `TCP 80, 443`  and `UDP 53`. Remove once installation is completed.

Install dependencies
```
apt update
apt-get install \
    git \
    apt-transport-https \
    ca-certificates \
    cron \
    curl \
    gnupg \
    lsb-release \
    vim
```

Add Docker's GPG Key
```
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
```

Add the stable repo:
```
echo \
  "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

Install Docker/Docker-compose:

```
apt-get update
apt-get install docker-ce docker-ce-cli containerd.io docker-compose
```

### Set up Repos and controls

Clone the cspm-lite repo
```
cd /root
git clone https://github.com/darkbitio/cspm-lite.git
```

Clone the controls repos:
```
cd /root
mkdir opencspm-controls
cd opencspm-controls
git clone https://github.com/OpenCSPM/opencspm-darkbit-community-controls.git
cd opencspm-darkbit-community-controls
git checkout exp
```

Contact us if you need access to this repo:
```
cd /root/opencspm-controls
gcloud source repos clone github_opencspm_opencspm-darkbit-enterprise-controls-private --project=darkbit-io
mv github_opencspm_opencspm-darkbit-enterprise-controls-private opencspm-darkbit-enterprise-controls-private
cd opencspm-darkbit-enterprise-controls-private
git checkout exp
```

## Build docker image
```
cd /root/cspm-lite
./build.sh
```

## Run

### Run backend services

Disable apparmor (required on Ubuntu)
```
aa-remove-unknown
systemctl disable apparmor.service --now
```

Create the systemd unit
```
cat << EOF > /etc/systemd/system/cspm-lite.service
# /etc/systemd/system/cspm-lite.service
[Unit]
Description=CSPM Lite
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
StandardError=null
StandardOutput=null
WorkingDirectory=/root/cspm-lite/docker
ExecStart=/usr/bin/docker-compose up -d
ExecStop=/usr/bin/docker-compose down

[Install]
WantedBy=multi-user.target
EOF
```

Reload the systemd unit:
```
systemctl daemon-reload
```

Start the backend services
```
systemctl start cspm-lite
```

Verify containers are running:
```
# docker ps
CONTAINER ID   IMAGE                                      COMMAND                  CREATED          STATUS                             PORTS                                                 NAMES
0c7cc8bf8e74   grafana/grafana                            "/run.sh"                17 seconds ago   Up 5 seconds                       0.0.0.0:3000->3000/tcp, :::3000->3000/tcp             grafana
d614482165a2   redislabs/redisinsight:latest              "bash ./docker-entry…"   17 seconds ago   Up 16 seconds                      0.0.0.0:8001->8001/tcp, :::8001->8001/tcp             redis_ui
d2666a308632   victoriametrics/victoria-metrics:v1.58.0   "/victoria-metrics-p…"   17 seconds ago   Up 16 seconds                      9090/tcp, 0.0.0.0:9090->8428/tcp, :::9090->8428/tcp   victoria
b6214378f425   oliver006/redis_exporter                   "/redis_exporter -re…"   17 seconds ago   Up 16 seconds                      0.0.0.0:9121->9121/tcp, :::9121->9121/tcp             redis_exporter
2356a70248fe   gcr.io/opencspm/redisgraph:edge-0.0.1      "docker-entrypoint.s…"   18 seconds ago   Up 17 seconds                      0.0.0.0:6379->6379/tcp, :::6379->6379/tcp             redis
dda3395ba717   gcr.io/cadvisor/cadvisor:latest            "/usr/bin/cadvisor -…"   18 seconds ago   Up 17 seconds (health: starting)   0.0.0.0:9091->8080/tcp, :::9091->8080/tcp             cadvisor
```

### Run CSPM pipeline
```
# If running not on GCE instance
gcloud auth application-default login
# Auth via browser to current user identity
# Paste code back in
# Select the current project with the bucket
# Test access to see collection bucket: gs://db-tenant-<tenantid>-us-opencspm/
gsutil ls
```

Modify `run.sh`:
* Set env vars for project_id, bucket_name, start_date
* Remove mounts for local gcloud creds

```
cd /root/cspm-lite
vim run.sh
#!/usr/bin/env bash

IMAGE_PATH="gcr.io/opencspm/cspm-lite:latest"
CURRENT_DIR="$(pwd)"
COMMAND="${@:-rake -T}"
HOMEDIR="${HOME}"
START_DATE="2021-05-26"
#PROJECT_ID="$(gcloud config get-value project)"
PROJECT_ID="db-tenant-<tenantid>"
BUCKET_NAME="db-tenant-<tenantid>-us-opencspm"
docker run --rm --net="docker_cspm" \
  -v "${CURRENT_DIR}/data:/app/data" \
  -v "${CURRENT_DIR}/../opencspm-controls:/opencspm-controls" \
  -e RAKE_PROJECT_ID="${PROJECT_ID}" \
  -e RAKE_START_DATE="${START_DATE}" \
  -e RAKE_BUCKET_NAME="${BUCKET_NAME}" \
  -e GOOGLE_AUTH_SUPPRESS_CREDENTIALS_WARNINGS=true \
  "${IMAGE_PATH}" ${COMMAND}
```

Remove the temporary egress firewall rule if enabled above.

Run manually:
```
./run.sh rake run:all
```

If the manual run works, configure the daily cronjob:
```
systemctl enable --now cron
crontab -e
```

Append the following line:
```
6 5 * * * cd /root/cspm-lite && ./run.sh rake run:all >> /tmp/run.log 2>&1
```

To view the results, disconnect from the SSH session and restart it with a port forward for `TCP 3000`.
```
exit
gcloud beta compute ssh --zone "us-central1-a" "db-tenant-<tenantid>-cspm-lite-vm"  --tunnel-through-iap --project "db-tenant-<tenantid>" -- -L 3000:localhost:3000
```

To view the last run:
```
tail /tmp/run.log
```

Open [http://localhost:3000](http://localhost:3000) and log in with `admin/admin`.  Change the password as requested.
