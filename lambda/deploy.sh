#!/bin/bash

echo "🚀 Deploying Project Nova Lambda Functions..."

# Get Lambda role ARN from Terraform
LAMBDA_ROLE_ARN=$(cd ../terraform && terraform output -raw lambda_role_arn)

# Create deployment packages (without boto3)
echo "📦 Creating deployment packages..."
zip -r9 rds_backup.zip rds_backup.py
zip -r9 cross_region_copy.zip cross_region_copy.py

# Deploy backup function
echo "⚡ Deploying RDS Backup function..."
aws lambda create-function \
    --function-name project-nova-rds-backup \
    --runtime python3.9 \
    --role "$LAMBDA_ROLE_ARN" \
    --handler rds_backup.lambda_handler \
    --zip-file fileb://rds_backup.zip \
    --timeout 300 \
    --memory-size 128 \
    --region ap-south-1 \
    --description "Creates automated RDS snapshots daily at 2 AM" || {
        echo "Function may already exist, updating code..."
        aws lambda update-function-code \
            --function-name project-nova-rds-backup \
            --zip-file fileb://rds_backup.zip \
            --region ap-south-1
    }

# Deploy cross-region copy function
echo "⚡ Deploying Cross-Region Copy function..."
aws lambda create-function \
    --function-name project-nova-cross-region-copy \
    --runtime python3.9 \
    --role "$LAMBDA_ROLE_ARN" \
    --handler cross_region_copy.lambda_handler \
    --zip-file fileb://cross_region_copy.zip \
    --timeout 300 \
    --memory-size 128 \
    --region ap-south-1 \
    --description "Copies RDS snapshots to Singapore DR region at 3 AM" || {
        echo "Function may already exist, updating code..."
        aws lambda update-function-code \
            --function-name project-nova-cross-region-copy \
            --zip-file fileb://cross_region_copy.zip \
            --region ap-south-1
    }

# Clean up zip files
rm -f *.zip

echo "✅ Lambda deployment complete!"
