import json
import boto3
import logging
import os
import sys

from custom_encoder import CustomEncoder

logger = logging.getLogger()
logger.setLevel(logging.INFO)

dynamodbTableName = 'counter-table'
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(dynamodbTableName)
client = boto3.client('dynamodb')

def lambda_handler(event, context):
    """Sample pure Lambda function
    """

    return updateVisitorCount()

    
    
def updateVisitorCount():
    try:
        response = client.update_item(
        TableName=dynamodbTableName,
        Key={"counter": {"N": "0"}},
        ReturnValues='UPDATED_NEW',
        UpdateExpression="ADD visitcount :inc",
        ExpressionAttributeValues={":inc": {"N": "1"}}
        )
        
        updatedValue = response["Attributes"]["visitcount"]["N"]

        body = {
            'Operation': 'UPDATE',
            'Message': 'SUCCESS',
            'CurrentCount': updatedValue,
            'UpdateAttributes': response
        }
        print(body)
        return buildResponse(200, body)
    except:
        logger.exception('Error in the updateVisitorCount function!!!')

def buildResponse(statusCode, body=None):

    return{
        'statusCode': statusCode,
        'body': json.dumps(body, cls=CustomEncoder),
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
        }
    }