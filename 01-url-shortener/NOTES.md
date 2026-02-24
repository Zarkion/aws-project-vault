# Notes – <Module X: Project Name>

## Topics
-Tech → AWS Project Vault → Project 1: URL Shortener

## Resources
- API Gateway
- Lambda
- DynamoDB
- Cloudwatch

## Notes (my takeaways)
- Invoke URL: https://56auf1dkd5.execute-api.us-east-1.amazonaws.com/prod
- Biggest blocker: During testing for GET, was getting back 403 MissingAuthenticationTokenException responses. Fix was to use curl.exe through Powershell instead of curl in Git Bash

## Habit-Checkin
- 2025-08-23 — 50 min — What worked / Next step:
- 2026-02-23 — 30 min — created POST method and lambda function / Create Lambda "Redirect" Function (GET /{shortCode})
2026-02-24 — 53 min — created GET method and lambda function, ran end-to-end tests, completed project