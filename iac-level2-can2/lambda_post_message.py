import os
import json
import boto3
from datetime import datetime


def lambda_handler(event, context):
    user_id = os.environ['USER_IDENTIFIER']
    table_name = f"ChatTable_{user_id}"
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table(table_name)
    sns = boto3.client('sns')

    print('user_id: ', user_id)
    print('table_name: ', table_name)

    # Check if the event contains a body
    if 'body' not in event:
        return {
            'statusCode': 400,
            'body': 'Missing request body'
        }

    # Parse the JSON payload
    try:
        body = json.loads(event['body'])
        message = body['message']

        print('user_id: ', user_id)
        print('message: ', message)
    except (KeyError, json.JSONDecodeError):
        return {
            'statusCode': 400,
            'body': 'Invalid or missing user_id or message'
        }

    # Current timestamp
    timestamp = str(datetime.utcnow())

    # Save message to DynamoDB
    table.put_item(
        Item={
            'userId': user_id,
            'timestamp': timestamp,
            'message': message,
            'direction': 'outgoing'
        }
    )

    # Publish message to the common SNS topic
    sns.publish(
        TopicArn='arn:aws:sns:us-east-1:000000007710:common-training-topic',
        Message=json.dumps({
            'user_id': user_id,
            'message': message,
            'timestamp': timestamp
        }),
        Subject='New Message'
    )

    return {
        'statusCode': 200,
        'body': 'Message sent successfully'
    }
