# Mailculator

Mailculator is a powerful open-source platform designed for high-volume email delivery using AWS SES. It provides developers and businesses with a scalable, user-centric solution for managing outbound email communication. With its focus on efficiency and precision, Mailculator offers robust tools for submitting email queues, tracking delivery statuses, and optimizing email campaigns.

## Key Features

- **High-Volume Email Delivery:** Built to handle large-scale email dispatching with AWS SES.
- **User-Based Differentiation:** Provides granular control over email queues and individual messages.
- **Monitoring & Management:** Includes tools to track sent messages, analyze delivery statuses, and troubleshoot failures.
- **Web Interface & API:** Offers flexibility for users to manage their communication via a modern web interface or programmatically through APIs.
- **Scalable Architecture:** Designed to meet the needs of both small teams and enterprise-scale operations.

---

## Services

Mailculator is composed of three interconnected services:

### 1. HTTP Acceptance API

This API handles the creation of message queues, grouped by user, and serves as the entry point for email submission.

#### Resources

- Requires an input directory shared via NFS with the caller.
- Shares a "maildir" directory (via NFS) with the other two services.

Repository: [mailculator-server](https://github.com/Multidialogo/mailculator-server)

---

### 2. Workload Processor

The workload processor is responsible for managing and processing email queues, ensuring timely delivery of messages.

#### Resources

- Shares a "maildir" directory (via NFS) with the other two services.

Repository: [mailculator-processor](https://github.com/Multidialogo/mailculator-processor)

---

### 3. Maildir Browser

The Maildir Browser provides a user-friendly web interface to explore and manage the "maildir" directory. Users can review sent messages, inspect delivery statuses, and analyze failures.

#### Resources

- Shares a "maildir" directory (via NFS) with the other two services.

Repository: [mailculator-filebrowser](https://github.com/Multidialogo/mailculator-filebrowser)

---

## Quick Start with Docker Compose

### Step 1: Retrieve Development Service Images

To set up Mailculator locally, you need to build the service images for the three components. Follow the instructions in each repository:

- [Mailculator Server](https://github.com/Multidialogo/mailculator-server/README.md)
- [Mailculator Processor](https://github.com/Multidialogo/mailculator-processor/README.md)
- [Mailculator Filebrowser](https://github.com/Multidialogo/mailculator-filebrowser/README.md)

Once built, you will have the required Docker images on your local machine.

---

### Step 2: Start the Services Locally

Use Docker Compose to spin up the services:

```bash
docker compose --env-file .env.dev down -v --remove-orphans && \
docker compose --env-file .env.dev -f docker-compose.yml up --force-recreate
```

This command uses the `.env.dev` file for environment variables and ensures the services are rebuilt and started fresh.

---

### Step 3: Generate Dummy Data
Create sample email queues for testing:

```bash
sudo chown -R "$(whoami):$(id -gn)" ./data && \
sudo chown -R "$(whoami):$(id -gn)" ./tmp && \
sudo ./generate_dummies.sh > generate_dummies.log 2>&1
```

This command prepares the necessary directories and generates dummy data for testing purposes. The output is logged to `generate_dummies.log`.

---

### Step 4: Access the Maildir Browser

Open the local Maildir Browser instance in your web browser:

[http://127.0.0.1:8102](http://127.0.0.1:8102)

#### Default Login Credentials

- **Admin Access:**

    - Username: `admin`
    - Password: `admin`

- **User Access:**

    - Username: `userId` (replace with the actual user ID)
    - Password: `password(userId)`

---

## Contributing

Mailculator is open source and welcomes contributions from the community. If you'd like to contribute, please refer to the contribution guidelines in each service repository.

---

With Mailculator, you can efficiently manage high-volume email delivery while maintaining granular control and monitoring. Start using Mailculator today and elevate your email campaigns to the next level!

