import socket
import boto3
import os

def lambda_handler(event, context):
    target_host = "www.google.com"
    target_port = 80
    
    # Get the SNS Topic ARN from an environment variable set by Terraform
    sns_topic_arn = os.environ.get('SNS_TOPIC_ARN')
    
    if not sns_topic_arn:
        print("SNS_TOPIC_ARN environment variable not set. Cannot send alerts.")
        return {
            'statusCode': 500,
            'body': "SNS_TOPIC_ARN not configured"
        }

    try:
        # Try to make a socket connection to Google
        sock = socket.create_connection((target_host, target_port), timeout=3)
        print(f"Successfully connected to {target_host}")
        sock.close()
        return {
            'statusCode': 200,
            'body': "Connection Successful"
        }
    except Exception as e:
        print(f"Failed to connect to {target_host}. Error: {str(e)}")
        
        # If connection fails, send an SNS alert
        sns = boto3.client('sns')
        
        sns.publish(
            TopicArn=sns_topic_arn,
            Message="ALERT: The Private Subnet cannot reach the internet! Check NAT Gateway.",
            Subject="Network Reachability Failure"
        )
        raise e # Make the lambda fail