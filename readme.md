# cspm-lite

## Build docker image
./build.sh

## Run

### Setup backend
cd docker && docker compose up -d

### Run CSPM pipeline
cd .. && ./run.sh rake run:all
