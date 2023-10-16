import json
import boto3

s3_client = boto3.client('s3')
sns_client = boto3.client('sns')


def lambda_handler(event, context):
    # Get bucket and file key from the S3 event
    bucket = event['Records'][0]['s3']['bucket']['name']
    key = event['Records'][0]['s3']['object']['key']

    print('key: ', key)

    # Fetch the file from S3
    message_content = s3_client.get_object(Bucket=bucket, Key=key)
    file_content = message_content['Body'].read().decode('utf-8')
    print('file_content: ', file_content)

    json_message = json.dumps({
        'bucket': bucket,
        'key': key,
        'file_content': file_content
    })

    # Publish the file content to SNS
    sns_response = sns_client.publish(
        TopicArn='arn:aws:sns:us-east-1:000000007710:common-training-topic',
        Message=json_message,
        Subject='New File Added to S3'
    )
    print('sns_response: ', sns_response)

    # Move the file within S3
    destination_key = key.replace("SEND/", "SENT/")
    copy_source = {'Bucket': bucket, 'Key': key}

    s3_client.copy_object(Bucket=bucket, CopySource=copy_source, Key=destination_key)
    s3_client.delete_object(Bucket=bucket, Key=key)

    return {
        'statusCode': 200,
        'body': json.dumps('File moved and content published to SNS')
    }
