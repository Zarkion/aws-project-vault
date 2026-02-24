# AWS Project — Module 1
**Goal:** Create a basic URL shortener that runs on AWS.

**Architecture:** API Gateway with GET and POST methods, POST takes a url as a parameter and passes it to a shorten function, which generates a random key string, stores the key/url pair in dynamoDB, and returns the redirect address and the code. GET takes a code at the end of the path and returns a 302 redirect response to the url associated with the code.

**How to run:**
curl -sS -X POST \
-H "Content-Type: application/json" \
-d '{"url":"https://aws.amazon.com"}' \
https://56auf1dkd5.execute-api.us-east-1.amazonaws.com/prod/shorten
curl.exe -i https://56auf1dkd5.execute-api.us-east-1.amazonaws.com/prod/ePCz8S

**Acceptance checklist:**
Create OK
Bad JSON
Missing url
Invalid scheme
Redirect OK
Code missing
Code unknown
Internal error

**Portfolio deliverables:** Screenshots of DynamoDB table item, API methods, and curl outputs. Stored in /screenshots
**Cleanup:**
- **API Gateway:** delete the API (removes stage)
- **Lambda:** delete both functions
- **DynamoDB:** delete `UrlShortener` table
- **IAM:** remove inline policy or role if not reused
- **Route 53 / ACM:** remove custom domain resources if created
