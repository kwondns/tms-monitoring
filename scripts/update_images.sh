#!/bin/bash
set -e

cd /opt/monitoring

# ECR 로그인
echo "Logging into ECR..."
aws ecr get-login-password --region $AWS_DEFAULT_REGION | sudo docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com

# 변경된 서비스만 이미지 pull
if [ -f changed_services.txt ]; then
  CHANGED_SERVICES=$(cat changed_services.txt)
  echo "Changed services: $CHANGED_SERVICES"

  if [ "$CHANGED_SERVICES" != "false" ]; then
    while read -r service; do
      if [ ! -z "$service" ]; then
        echo "Pulling updated image for $service..."
        sudo docker-compose pull "$service" || echo "Failed to pull $service, continuing..."
      fi
    done < changed_services.txt
  else
    echo "No services changed, skipping image pull"
  fi
fi

echo "Image update completed"
