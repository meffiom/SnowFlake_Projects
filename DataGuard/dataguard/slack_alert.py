import requests
import json

WEBHOOK_URL = "https://hooks.slack.com/services/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"

def send_alert(failures):
    message = {
        "blocks": [
            {
                "type": "header",
                "text": {
                    "type": "plain_text",
                    "text": "🚨 Data Quality Alert — DataGuard",
                    "emoji": True
                }
            },
            {
                "type": "section",
                "text": {
                    "type": "mrkdwn",
                    "text": "*The following checks FAILED:*"
                }
            },
            {
                "type": "section",
                "text": {
                    "type": "mrkdwn",
                    "text": "\n".join([f"❌ *{f}*" for f in failures])
                }
            }
        ]
    }
    response = requests.post(WEBHOOK_URL, data=json.dumps(message),
        headers={"Content-Type": "application/json"})
    return response.status_code == 200

def send_success():
    message = {
        "blocks": [
            {
                "type": "header",
                "text": {
                    "type": "plain_text",
                    "text": "✅ All Data Quality Checks Passed — DataGuard",
                    "emoji": True
                }
            },
            {
                "type": "section",
                "text": {
                    "type": "mrkdwn",
                    "text": "stg_customers, mart_offer_funnel, mart_customer_segments — all clean!"
                }
            }
        ]
    }
    response = requests.post(WEBHOOK_URL, data=json.dumps(message),
        headers={"Content-Type": "application/json"})
    return response.status_code == 200