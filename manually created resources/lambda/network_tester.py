import socket
import boto3

def lambda_handler(event, context):
    target_host = "www.google.com"
    target_port = 80
    
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
        # REPLACE WITH YOUR SNS TOPIC ARN from Phase 3, Part A
        topic_arn = "arn:aws:sns:us-east-1:123456789012:AdminAlertsTopic" 
        
        sns.publish(
            TopicArn=topic_arn,
            Message="ALERT: The Private Subnet cannot reach the internet! Check NAT Gateway.",
            Subject="Network Reachability Failure"
        )
        raise e # Make the lambda fail