import json
import boto3
import logging
import os
import sys
from decimal import Decimal

file_dir = os.path.dirname(__file__)
sys.path.append(file_dir)

from custom_encoder import CustomEncoder

logger = logging.getLogger()
logger.setLevel(logging.INFO)

dynamodbTableName = 'visitorCountTable'
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(dynamodbTableName)

getMethod = "GET"

def lambda_handler(event, context):
    """Sample pure Lambda function
    """
    httpMethod = event["httpMethod"]
    countKey = "visitsCount" 

    if httpMethod == getMethod:
        responseGet = getCurrentVisitorCount(countKey)

        if responseGet['body'] == '{}': 
            response = updateVisitorCount(countKey, 0)    
        else:
            response = updateVisitorCount(countKey, int(float(responseGet['body'])))
    else:
         response = buildResponse(404, 'Unsupported Request')
         
    return response

def getCurrentVisitorCount(tablePrtKey):

    try:
        response = table.get_item(
            Key = {
                'visitsCount': tablePrtKey
                })      
        if 'Item' in response:
            return buildResponse(200, response['Item']['visitsValue'])
        else:
            return buildResponse(200, {})
    except:
        logger.exception('Error retrieving value from DyanmoTable !!!')   

def updateVisitorCount(countKey, upDateValue):
    
    try:
        response = table.update_item(
        Key={
            'visitsCount': countKey
        },
        UpdateExpression='SET visitsValue = :increment',
        ExpressionAttributeValues={
            ':increment': upDateValue + 1
        })
        body = {
            'Operation': 'UPDATE',
            'Message': 'SUCCESS',
            'CurrentCount': upDateValue + 1,
            'UpdateAttributes': response
        }
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