import boto3
import json
from datetime import datetime

def lambda_handler(event, context):
    """
    Creates automated snapshots of RDS databases
    """
    rds = boto3.client('rds', region_name='us-east-1')
    
    try:
        # Get all RDS instances
        instances = rds.describe_db_instances()
        
        for instance in instances['DBInstances']:
            instance_id = instance['DBInstanceIdentifier']
            timestamp = datetime.now().strftime('%Y-%m-%d-%H-%M')
            snapshot_id = f"{instance_id}-backup-{timestamp}"
            
            # Create snapshot
            response = rds.create_db_snapshot(
                DBSnapshotIdentifier=snapshot_id,
                DBInstanceIdentifier=instance_id
            )
            
            print(f"✅ Created snapshot: {snapshot_id}")
            
            # Tag the snapshot
            rds.add_tags_to_resource(
                ResourceName=response['DBSnapshot']['DBSnapshotArn'],
                Tags=[
                    {'Key': 'Environment', 'Value': 'Production'},
                    {'Key': 'BackupType', 'Value': 'Automated'},
                    {'Key': 'Project', 'Value': 'ProjectNova'}
                ]
            )
            
        return {
            'statusCode': 200,
            'body': json.dumps('RDS backup completed successfully')
        }
        
    except Exception as e:
        print(f"❌ Error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error: {str(e)}')
        }
