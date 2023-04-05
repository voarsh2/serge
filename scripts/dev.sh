#!/bin/bash
./compile.sh 

pip install -e ./api

redis-server &
mongod --quiet --logpath /dev/null &

# Start the orchestrator
python3 /usr/src/app/api/src/serge/worker/orchestrator.py &

# Start the web server
cd web && npm run dev -- --host 0.0.0.0 --port 8008 &
  
# Start the API
cd api && uvicorn src.serge.main:api_app --reload --host 0.0.0.0 --port 9124 --root-path /api/ &
# Wait for any process to exit
wait -n
# Exit with status of process that exited first
exit $?
