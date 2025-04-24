#!/bin/bash

set -ex

cd /opt/deploy/data-access-tool-backend/
docker compose up --detach
