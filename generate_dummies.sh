#!/bin/bash

# Enabling strict error handling
set -euo pipefail  # Exit on error, treat unset variables as errors, fail on pipeline errors

CREATE_QUEUES_URL="http://localhost:8101/email-queues"
LOCAL_INPUT_DUMMY_FILES_DIR="./data/input"
DUMMY_FILES_DIR="${LOCAL_INPUT_DUMMY_FILES_DIR}/dummies"
OUTBOX_DIR="./data/maildir/outbox"
USERS_DIR="./data/maildir/users"

FB_ADMIN_AUTH_TOKEN="TO-GET"
FB_AUTH_URL="http://localhost:8102/api/login"
FB_USER_CREATE_URL="http://localhost:8102/api/users"
FB_ADMIN_USERNAME="admin"
FB_ADMIN_PASSWORD="admin"

# Download sample datasets
download_samples() {
  rm -rf "${DUMMY_FILES_DIR}"
  rm -rf ./tmp

  mkdir -p "${DUMMY_FILES_DIR}"
  mkdir -p ./tmp

  # Download the dataset
  curl -L -o ./tmp/dog-poop-dataset.zip https://www.kaggle.com/api/v1/datasets/download/wengjiyao/dog-poop-dataset

  # Extract the dataset to the target directory
  unzip ./tmp/dog-poop-dataset.zip -d ./tmp/dog-poop-dataset

  mkdir -p "${DUMMY_FILES_DIR}/pictures"
  mv ./tmp/dog-poop-dataset/dpd2024/test/poop/* "${DUMMY_FILES_DIR}/pictures"

  mkdir -p "${DUMMY_FILES_DIR}/pdf"

  # Define an array of file URIs
  PDF_FILES=(
    "https://archive.org/download/thetford-porta-potti-565-chemical-toilet/Thetford%20Porta%20Potti%20565%20chemical%20toilet.pdf"
    "https://archive.org/download/400-a-rubik-instructions-eng-span-5x-7.25-020118/400A_RUBIK_Instructions_Eng%EF%80%A2Span_5x7.25_020118.pdf"
  )

  # Loop through the array and download each file
  for FILE_URI in "${PDF_FILES[@]}"; do
    # Extract the filename from the URL
    FILENAME=$(basename "$FILE_URI")

    # Download the file using curl
    curl -L -o "${DUMMY_FILES_DIR}/pdf/${FILENAME}" "${FILE_URI}"
  done
}

# Get random files from the dummy data
get_random_files() {
  # Scan the directory recursively and store the paths in an array
  local files=($(find "${DUMMY_FILES_DIR}" -type f))

  # Check how many files are found
  local file_count=${#files[@]}

  # If there are fewer than 20 files, return all files available
  local random_count=$((file_count < ${1} ? file_count : ${1}))

  # Randomly shuffle the files and select the random_count
  local selected_files=()
  for i in $(shuf -i 0-$(($file_count - 1)) -n $random_count); do
    selected_files+=("${files[$i]//${LOCAL_INPUT_DUMMY_FILES_DIR}/}")
  done

  # Return the selected files as an array
  echo "${selected_files[@]}"
}

# Get the admin authentication token from FileBrowser
get_file_browser_admin_auth_token() {
  # Get the Bearer Token
  FB_ADMIN_AUTH_TOKEN=$(curl -s -X POST "${FB_AUTH_URL}" \
      -H "Content-Type: application/json" \
      -d "{
          \"username\": \"${FB_ADMIN_USERNAME}\",
          \"password\": \"${FB_ADMIN_PASSWORD}\"
      }")

  # Check if token retrieval was successful
  if [[ -z "${FB_ADMIN_AUTH_TOKEN}" ]]; then
      echo "Failed to retrieve admin token. Exiting..."
      exit 1
  fi
}

# Generate a new user on the FileBrowser server
generate_filebrowser_user() {
  local JSON_PAYLOAD=$(cat <<EOF
{"what":"user","which":[],"data":{"scope":"","locale":"it","viewMode":"list","singleClick":false,"sorting":{"by":"","asc":false},"perm":{"admin":false,"execute":false,"create":false,"rename":false,"modify":false,"delete":false,"share":false,"download":true},"commands":[],"hideDotfiles":true,"dateFormat":false,"username":"${1}","password":"password${1}","rules":[],"lockPassword":true,"id":0}}
EOF
)

  local RESPONSE=$(curl -s -w "%{http_code}" -X POST "${FB_USER_CREATE_URL}" \
      -H "X-Auth: ${FB_ADMIN_AUTH_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "$JSON_PAYLOAD")

  # Get HTTP code and response body
  local HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
  local RESPONSE_BODY=$(echo "$RESPONSE" | sed '$d')

  # Log the response body and status code
  echo "Response: $HTTP_CODE"
  echo "Response body: $RESPONSE_BODY"

  if [ "$HTTP_CODE" -ne 201 ]; then
     echo "Failed to create user user${1}. HTTP Response: $HTTP_CODE"
     exit 1
  else
     echo "User ${1} created successfully!"
  fi
}

# Create email queues for a user
create_user_email_queues() {
  local userID=$((RANDOM % 1000))

  echo "Generating user on filebrowser server"
  generate_filebrowser_user "${userID}"

  echo "Generating queues for user id ${userID}"

  for ((q=1; q<$((RANDOM % 3)); q++)); do
    local queueUUID=$(uuidgen)
    echo "Generating queue ${queueUUID} for user id ${userID}"

    # Start the JSON array for the messages
    local request_body='{"data":['

    # Loop through the number of messages and create a unique messageUUID for each
    local total_messages=$((RANDOM % 100))
    for ((i=1; i<total_messages; i++)); do
      echo "Generating ${i} attachments for queue ${queueUUID} for user id ${userID}"

      # Call get_random_files to get an array of random files
      local files=($(get_random_files $((RANDOM % 6))))

      # Construct the attachments JSON
      local attachments_json="[]"
      for file in "${files[@]}"; do
        attachments_json=$(echo "$attachments_json" | jq ". + [\"$file\"]")
      done

      # Construct each message's JSON object
      local message=$(cat <<EOF
{
  "id": "$userID:$queueUUID:$(uuidgen)",
  "type": "email",
  "attributes": {
    "from": "sender@example.com",
    "replyTo": "replyto@example.com",
    "to": "recipient@example.com",
    "subject": "Test Email $i",
    "bodyHTML": "<h1>Hello</h1><p>This is a test email with attachments.</p>",
    "bodyText": "Hello, This is a test email with attachments.",
    "attachments": $attachments_json,
    "customHeaders": {
      "X-Custom-Header": "CustomValue"
    }
  }
}
EOF
)

      # Append the message to the request_body array
      if [[ $i -gt 0 ]]; then
        request_body="$request_body,$message"
      else
        request_body="$request_body$message"
      fi
    done

    # Close the JSON array after the loop
    request_body="$request_body]}"

    echo "\n\nREQUEST\n\n${request_body}\n\n"

    # Send all messages for this queue in a single request
    curl -X POST "${CREATE_QUEUES_URL}" \
      -H "Content-Type: application/json" \
      -d "$request_body"
  done
}

# Cleanup existing directories
rm -rf "${OUTBOX_DIR}/users"
rm -rf "${USERS_DIR}"

# If the flag "--ds" is passed, download samples
if [[ "$1" == "--ds" ]]; then
  echo "Downloading samples..."
  download_samples
fi

# Get the FileBrowser admin token
get_file_browser_admin_auth_token

# Create users and their email queues
for i in {1..10}; do
  echo "Creating user ${i} queues"
  create_user_email_queues
done
