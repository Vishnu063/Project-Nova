import boto3
import json

def lambda_handler(event, context):
    """
    Copies RDS snapshots to DR region
    """
    source_rds = boto3.client('rds', region_name='us-east-1')
    dest_rds = boto3.client('rds', region_name='us-west-2')
    
    try:
        # Get latest snapshots
        snapshots = source_rds.describe_db_snapshots(
            SnapshotType='manual',
            IncludePublic=False
        )
        
        # Group snapshots by instance and find latest
        latest_snapshots = {}
        for snapshot in snapshots['DBSnapshots']:
            instance_id = snapshot['DBInstanceIdentifier']
            
            if instance_id not in latest_snapshots:
                latest_snapshots[instance_id] = snapshot
            else:
                current = snapshot['SnapshotCreateTime']
                latest = latest_snapshots[instance_id]['SnapshotCreateTime']
                if current > latest:
                    latest_snapshots[instance_id] = snapshot
        
        # Copy latest snapshots to DR region
        copied_count = 0
        for instance_id, snapshot in latest_snapshots.items():
            source_arn = snapshot['DBSnapshotArn']
            snapshot_name = snapshot['DBSnapshotIdentifier']
            dr_snapshot_id = f"dr-copy-{snapshot_name}"
            
            # Check if snapshot already exists in DR
            try:
                dest_rds.describe_db_snapshots(
                    DBSnapshotIdentifier=dr_snapshot_id
                )
                print(f"⚠️ Snapshot {dr_snapshot_id} already exists in DR")
                continue
            except:
                pass
            
            # Copy snapshot
            response = dest_rds.copy_db_snapshot(
                SourceDBSnapshotIdentifier=source_arn,
                TargetDBSnapshotIdentifier=dr_snapshot_id,
                CopyTags=True
            )
            
            print(f"✅ Copying {snapshot_name} to DR region")
            copied_count += 1
        
        return {
            'statusCode': 200,
            'body': json.dumps(f'Cross-region copy completed. Copied {copied_count} snapshots.')
        }
        
    except Exception as e:
        print(f"❌ Error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error: {str(e)}')
        }
