#!/usr/bin/env python3
"""
Simple email notification script for CI/CD pipeline
Requires: pip install requests

Usage:
  python3 scripts/send_email.py "Subject" "Body content" "recipient@email.com"
"""

import sys
import json
import os
from urllib.request import Request, urlopen
from urllib.parse import urlencode

def send_email_via_formspree(subject, body, recipient):
    """
    Send email using Formspree (free service)
    You need to create a form at https://formspree.io/ and get the form ID
    """
    # Replace 'YOUR_FORM_ID' with your actual Formspree form ID
    form_id = os.environ.get('FORMSPREE_FORM_ID', 'YOUR_FORM_ID')
    
    if form_id == 'YOUR_FORM_ID':
        print("Warning: FORMSPREE_FORM_ID not set. Email not sent.")
        print(f"Would send email to: {recipient}")
        print(f"Subject: {subject}")
        print(f"Body: {body}")
        return
    
    url = f"https://formspree.io/f/{form_id}"
    
    data = {
        'email': recipient,
        'subject': subject,
        'message': body
    }
    
    try:
        req = Request(url, data=urlencode(data).encode(), method='POST')
        req.add_header('Content-Type', 'application/x-www-form-urlencoded')
        
        with urlopen(req) as response:
            if response.status == 200:
                print(f"Email sent successfully to {recipient}")
            else:
                print(f"Failed to send email. Status: {response.status}")
    except Exception as e:
        print(f"Error sending email: {e}")

def send_email_via_github_api(subject, body, recipient):
    """
    Alternative: Use GitHub API to create an issue as notification
    This doesn't send actual email but creates a GitHub issue
    """
    github_token = os.environ.get('GITHUB_TOKEN')
    repo = os.environ.get('GITHUB_REPOSITORY')
    
    if not github_token or not repo:
        print("GitHub token or repository not available")
        return
    
    url = f"https://api.github.com/repos/{repo}/issues"
    
    issue_data = {
        'title': f"CI/CD Notification: {subject}",
        'body': f"**Notification for:** {recipient}\n\n{body}",
        'labels': ['ci-cd', 'notification']
    }
    
    try:
        req = Request(url, data=json.dumps(issue_data).encode(), method='POST')
        req.add_header('Authorization', f'token {github_token}')
        req.add_header('Content-Type', 'application/json')
        
        with urlopen(req) as response:
            if response.status == 201:
                print(f"GitHub issue created as notification for {recipient}")
            else:
                print(f"Failed to create GitHub issue. Status: {response.status}")
    except Exception as e:
        print(f"Error creating GitHub issue: {e}")

def main():
    if len(sys.argv) != 4:
        print("Usage: python3 send_email.py 'Subject' 'Body' 'recipient@email.com'")
        sys.exit(1)
    
    subject = sys.argv[1]
    body = sys.argv[2]
    recipient = sys.argv[3]
    
    # Try Formspree first, fallback to GitHub issue
    send_email_via_formspree(subject, body, recipient)
    
    # Uncomment the line below if you want to also create a GitHub issue
    # send_email_via_github_api(subject, body, recipient)

if __name__ == '__main__':
    main()