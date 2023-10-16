import json
import boto3
import os

s3 = boto3.client('s3')
bucket_name = os.environ['BUCKET_NAME']  # The bucket name is passed from the environment variables


def lambda_handler(event, context):
    try:
        message = event['Records'][0]['Sns']['Message']
        print("Received message:", message)

        message_json = json.loads(message)

        # Upload the message to the S3 bucket under the "Received" folder

        file_content = message_json['file_content']
        bucket_from = message_json['bucket']
        tag_value = file_content[:256] if len(file_content) > 256 else file_content

        print('bucket_from: ', bucket_from)
        print('bucket_name: ', bucket_name)
        if bucket_from == bucket_name:
            file_name = f">>-->: {tag_value}"
        else:
            file_name = f"{bucket_from}: {tag_value}"

        print('file_name: ', file_name)
        print('tag_value: ', tag_value)
        print('bucket_name: ', bucket_name)

        s3.put_object(Body=message,
                      Bucket=bucket_name,
                      Key=f'CHAT/{file_name}')

        return {
            'statusCode': 200,
            'body': json.dumps('Successfully processed message!')
        }
    except Exception as e:
        print("Error:", e)
        return {
            'statusCode': 500,
            'body': json.dumps('Failed to process message.')
        }
