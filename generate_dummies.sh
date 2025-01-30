#!/bin/bash

CREATE_QUEUES_URL="http://localhost:8101/email-queues"
LOCAL_INPUT_DUMMY_FILES_DIR="./data/input"
DUMMY_FILES_DIR="${LOCAL_INPUT_DUMMY_FILES_DIR}/dummies"
OUTBOX_DIR="./data/maildir/outbox"
USERS_DIR="./data/maildir/users"

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
    # Substitute $LOCAL_INPUT_DUMMY_FILES_DIR with $CONTAINER_LOCAL_INPUT_DUMMY_FILES_DIR in the selected file path
    selected_files+=("${files[$i]//${LOCAL_INPUT_DUMMY_FILES_DIR}/}")
  done

  # Return the selected files as an array
  echo "${selected_files[@]}"
}

create_user_email_queues() {
  local userID=$((RANDOM % 1000))

  echo "Generating queues for user id ${userID}"

  for ((q=0; q<$((RANDOM % 3)); q++)); do
    local queueUUID=$(uuidgen)
    echo "Generating queue ${queueUUID} for user id ${userID}"

    # Start the JSON array for the messages
    local request_body='{"data":['

    # Loop through the number of messages and create a unique messageUUID for each
    local total_messages=$((RANDOM % 100))
    for ((i=0; i<total_messages; i++)); do
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

    # Send all messages for this queue in a single request
    curl -X POST "${CREATE_QUEUES_URL}" \
      -H "Content-Type: application/json" \
      -d "$request_body"
  done
}

rm -rf "${OUTBOX_DIR}/users"
rm -rf "${USERS_DIR}"

if [[ "$1" == "--ds" ]]; then
  echo "Downloading samples..."
  download_samples > /dev/null 2>&1
fi

for i in {1..10}; do
  echo "Creating user ${i} queues"
  create_user_email_queues > /dev/null 2>&1
done




