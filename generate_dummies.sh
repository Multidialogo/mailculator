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

MAX_QUEUES_PER_USER=$((3 -1))
MAX_MESSAGES_PER_QUEUE=$((4000 -1))
AVERAGE_MAX_MESSAGES_PER_QUEUE=$((80 -1))
TOTAL_USERS=4

TOTAL_EXPECTED_GENERATED_MESSAGES=0
TOTAL_EXPECTED_GENERATED_QUEUES=0

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
  find ./tmp/dog-poop-dataset/dpd2024/test/poop/ -type f ! -name '*_frame_*' -exec mv {} "${DUMMY_FILES_DIR}/pictures" \;

  mkdir -p "${DUMMY_FILES_DIR}/pdf"

  # Define an array of file URIs
  PDF_FILES=(
    "https://archive.org/download/thetford-porta-potti-565-chemical-toilet/Thetford%20Porta%20Potti%20565%20chemical%20toilet.pdf"
    "https://archive.org/download/400-a-rubik-instructions-eng-span-5x-7.25-020118/400A_RUBIK_Instructions_Eng%EF%80%A2Span_5x7.25_020118.pdf"
    "https://archive.org/download/imitation-game-the/Imitation_Game_The.pdf"
    "https://archive.org/download/TuringTheEnigma/turing%20the%20enigma.pdf"
    "https://archive.org/download/arxiv-1206.1706/1206.1706.pdf"
    "https://archive.org/download/arxiv-dg-ga9610016/dg-ga9610016.pdf"
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
  local userID=$((RANDOM % 10000000))
  local total_queues=$((RANDOM % MAX_QUEUES_PER_USER + 1))
  echo "Generating ${total_queues} queues for user id ${userID}"

  for ((q=1; q<=${total_queues}; q++)); do
    TOTAL_EXPECTED_GENERATED_QUEUES=$((TOTAL_EXPECTED_GENERATED_QUEUES + 1))

    local queueUUID=$(uuidgen)

    # Start the JSON array for the messages
    local request_body='{"data":['

    # Loop through the number of messages and create a unique messageUUID for each
    if [ $((TOTAL_EXPECTED_GENERATED_QUEUES % TOTAL_USERS)) -eq 0 ]; then
      local total_messages=$((MAX_MESSAGES_PER_QUEUE +1))
    else
      local total_messages=$((RANDOM % AVERAGE_MAX_MESSAGES_PER_QUEUE +1))
    fi
    echo "Generating ${total_messages} messages for queue ${queueUUID} for user id ${userID}"
    for ((i=1; i<=total_messages; i++)); do
      echo -n "."
      if [  $((i % 120)) -eq 0 ]; then
        echo ""
      fi
      TOTAL_EXPECTED_GENERATED_MESSAGES=$((TOTAL_EXPECTED_GENERATED_MESSAGES + 1))
      # Call get_random_files to get an array of random files
      local total_attachments=$((RANDOM % 9 + 1))
      local files=($(get_random_files ${total_attachments}))

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
      if [[ $i -gt 1 ]]; then
        request_body="$request_body,$message"
      else
        request_body="$request_body$message"
      fi
    done
    echo ""

    # Close the JSON array after the loop
    request_body="$request_body]}"

    # Save request_body in text file and then send it via curl
    echo "${request_body}" > ./tmp/request_body.json

    # Usa curl per inviare la richiesta con il corpo del file
    curl -X POST "${CREATE_QUEUES_URL}" \
      -H "Content-Type: application/json" \
      -d @./tmp/request_body.json
  done

  echo "Generating user on filebrowser server"
  generate_filebrowser_user "${userID}"
}

# Cleanup existing directories
rm -rf "${OUTBOX_DIR}/users"
rm -rf "${USERS_DIR}"

# If the flag "--ds" is passed, download samples
if [[ "${1:-}" == "--ds" ]]; then
  echo "Downloading samples..."
  download_samples > /dev/null 2>&1
fi

# Get the FileBrowser admin token
get_file_browser_admin_auth_token

# Create users and their email queues
for i in $(seq 1 ${TOTAL_USERS}); do
  echo "Creating queues for user id ${i}..."
  create_user_email_queues "$i"
done

echo "${TOTAL_USERS} generated users"
echo "${TOTAL_EXPECTED_GENERATED_QUEUES} generated queues"
echo "${TOTAL_EXPECTED_GENERATED_MESSAGES} generated messages"

echo "Checking number of produced messages"

TOTAL_GENERATED_MESSAGES=$(find ${USERS_DIR} -type f -name "*.EML" | wc -l)

echo "${TOTAL_GENERATED_MESSAGES} generated messages"


