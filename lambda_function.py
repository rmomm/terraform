import boto3
import os

def handler(event, context):
  
    s3 = boto3.client('s3', endpoint_url='http://host.docker.internal:4566')

  
    source_bucket = os.environ['SOURCE_BUCKET']
    destination_bucket = os.environ['DEST_BUCKET']

  
    for record in event['Records']:
        key = record['s3']['object']['key']

        copy_source = {'Bucket': source_bucket, 'Key': key}


        s3.copy_object(Bucket=destination_bucket, CopySource=copy_source, Key=key)
        print(f"Copied {key} from {source_bucket} to {destination_bucket}")