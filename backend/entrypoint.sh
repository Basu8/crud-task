#!/bin/sh
# backend/entrypoint.sh
set -e

# Default mongo url if not provided
: "${MONGO_URL:=mongodb://mongo:27017/dd_db}"

cat > ./app/config/db.config.js <<EOF
module.exports = {
  url: "${MONGO_URL}"
};
EOF

# optionally set PORT
: "${PORT:=8080}"
export PORT

echo "Starting server with MONGO_URL=${MONGO_URL} and PORT=${PORT}"
node server.js
