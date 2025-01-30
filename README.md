# MailCulator

The Mailculator project is a robust open-source platform designed for high-volume email delivery using AWS SES. It offers a powerful API for submitting email queues and individual messages, with user-based differentiation to ensure precise control over email dispatching.

Beyond just sending emails, Mailculator provides a comprehensive solution for monitoring and managing outbound communication. Through both a web interface and an API, users can track sent messages, review delivery statuses, and analyze failures, enabling better troubleshooting and optimization of email campaigns.

With its scalable architecture and focus on efficiency, Mailculator is an ideal choice for developers and businesses looking for a reliable, user-centric email dispatch system.

## Start with docker compose and development images:

```bash
docker compose --env-file .env.dev -f docker-compose.yml up
```

Send some dummy queues:
```bash
sudo chown -R michele:michele ./data && \
sudo chown -R michele:michele ./tmp && \
sudo ./generate_dummies.sh --ds
```

Check stuff:
Go to http://127.0.0.1:8102 and login with "admin" "admin".