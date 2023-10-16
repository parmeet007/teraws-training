import json
import boto3
import os

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['DYNAMODB_TABLE'])

def lambda_handler(event, context):
    # Fetch all items from DynamoDB table
    response = table.scan()

    return {
        'statusCode': 200,
        'body': json.dumps({'items': response['Items']}),
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
        }
    }
