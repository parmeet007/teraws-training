import os
import json
import boto3
from datetime import datetime


def lambda_handler(event, context):
    user_id = os.environ['USER_IDENTIFIER']
    table_name = f"ChatTable_{user_id}"
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table(table_name)

    # Extracting message from SNS event
    try:
        message = json.loads(event['Records'][0]['Sns']['Message'])
        userFromId = message['userId']
        msg_content = message['message']
        timestamp = message['timestamp']
    except (KeyError, IndexError, json.JSONDecodeError):
        return {
            'statusCode': 400,
            'body': 'Error in processing SNS message'
        }

    # Save the received message to DynamoDB
    if userFromId != user_id:
        table.put_item(
            Item={
                'userId': user_id,
                'timestamp': timestamp,
                'message': msg_content,
                'direction': 'incoming'
            }
        )

    return {
        'statusCode': 200,
        'body': 'Message received successfully'
    }
