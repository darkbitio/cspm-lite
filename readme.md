# cspm-lite

## Set up Repos and controls
```
cd ~
git clone https://https://github.com/darkbitio/cspm-lite.git
mkdir opencspm-controls
cd opencspm-controls
git clone https://github.com/OpenCSPM/opencspm-darkbit-community-controls.git
cd opencspm-darkbit-community-controls
git checkout exp
cd ..
git clone https://github.com/OpenCSPM/opencspm-darkbit-enterprise-controls-private.git
cd opencspm-darkbit-enterprise-controls-private
git checkout exp
cd ..
```

## Build docker image
```
cd ~/cspm-lite
./build.sh
```

## Run

### Run backend services
```
cd docker
docker compose up -d
```

### Run CSPM pipeline
```
cd ~/cspm-lite
# Modify run.sh env vars for project_id, bucket_name, start_date
# Modify run.sh mounts for local gcloud creds if not on GCE instance
./run.sh rake run:all
```
