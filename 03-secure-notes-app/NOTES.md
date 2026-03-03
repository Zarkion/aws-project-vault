# Notes – <Module 3: Secure Notes App>

## Topics
-Tech → AWS Project Vault → Project 3: Secure Notes (Auth)

## Resources
-

## Notes (my takeaways)
- Built a JWT‑secured serverless Notes API on AWS using Cognito (User Pool), API Gateway (Cognito authorizer), Lambda, and DynamoDB with per‑user isolation, clean error handling, and least‑privilege IAM; optional S3 attachments via presigned URLs.
- What I learned about JWTs and authorizers: JWTs are the basis of constant user authentication. Authorizers issue JWTs upon successful authentication of a client. 
- Biggest blockers: the JSON serializer was unable to handle the Decimal output of the time columns, so to make it work I had to cast them as strings before saving. Should this data be required in other microservices, it would need to be cast as an int before usage.


## Habit-Checkin
- 2025-08-23 — 50 min — What worked / Next step:
- 2026-02-26 - 120 min - things / step 3
- 2026-02-27 - 20 min - more things / step 5, my aches and pains are getting in the way and I just want to lie down.
- 2026-03-02 - 60 min - steps 5-8 of path / fix bugs.
- 2026-03-03 - 25 min - rest of the core path