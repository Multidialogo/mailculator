# MailCulator

The Mailculator project is a robust open-source platform designed for high-volume email delivery using AWS SES. It offers a powerful API for submitting email queues and individual messages, with user-based differentiation to ensure precise control over email dispatching.

Beyond just sending emails, Mailculator provides a comprehensive solution for monitoring and managing outbound communication. Through both a web interface and an API, users can track sent messages, review delivery statuses, and analyze failures, enabling better troubleshooting and optimization of email campaigns.

With its scalable architecture and focus on efficiency, Mailculator is an ideal choice for developers and businesses looking for a reliable, user-centric email dispatch system.

## Services

Mailculator is divided in 3 services:

## http acceptance API

@see https://github.com/Multidialogo/mailculator-server

Acceptance API allows to create message queues, grouped by user.

### Resources

- Needs an input directory that must be shared via NFS with the caller.
- Shares with the other two services a "maildir" directory (via NFS).

## workload processor

@see https://github.com/Multidialogo/mailculator-processor

### Resources

- Shares with the other two services a "maildir" directory (via NFS).

## maildir browser

@see https://github.com/Multidialogo/mailculator-filebrowser

### Resources

- Shares with the other two services a "maildir" directory (via NFS).

## Quick start with docker compose:

### Retrieve development service images

You can build service images from each of the service repository and following instructions:

- @see https://github.com/Multidialogo/mailculator-server/README.md
- @see https://github.com/Multidialogo/mailculator-processor/README.md
- @see https://github.com/Multidialogo/mailculator-filebrowser/README.md

This will give you on your local host the set of the three docker development images used in the next docker-compose, 
configuration:

```bash
docker compose --env-file .env.dev -f docker-compose.yml up
```

Send some dummy queues:
```bash
sudo chown -R "$(whoami):$(id -gn)" ./data && \
sudo chown -R "$(whoami):$(id -gn)" ./tmp && \
sudo ./generate_dummies.sh --ds
```

Check stuff:
Go to http://127.0.0.1:8102 and login with "admin" "admin".