#!/bin/bash

CREATE_QUEUES_URL="http://localhost:8101/email-queues"
DATA_DIR="./data"
CONTAINER_DATA_DIR="/var/lib/mailculator-server"
DUMMY_FILES_DIR="${DATA_DIR}/input/dummies"

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
    # Substitute $DATA_DIR with $CONTAINER_DATA_DIR in the selected file path
    selected_files+=("${files[$i]//${DATA_DIR}/${CONTAINER_DATA_DIR}}")
  done

  # Return the selected files as an array
  echo "${selected_files[@]}"
}


create_email_queue() {
  local userID=$(uuidgen)
  local queueUUID=$(uuidgen)
  local messageUUID=$(uuidgen)

  # Call get_random_files to get an array of random files
  local files=($(get_random_files ${1}))

  # Construct the request body JSON, including files as attachments
  local attachments_json="[]"
  for file in "${files[@]}"; do
    attachments_json=$(echo "$attachments_json" | jq ". + [\"$file\"]")
  done

  local request_body=$(cat <<EOF
{
  "data": {
    "id": "$userID:$queueUUID:$messageUUID",
    "type": "email",
    "attributes": {
      "from": "sender@example.com",
      "replyTo": "replyto@example.com",
      "to": "recipient@example.com",
      "subject": "Test Email",
      "bodyHTML": "<h1>Hello</h1><p>This is a test email with attachments.</p>",
      "bodyText": "Hello, This is a test email with attachments.",
      "attachments": $attachments_json,
      "customHeaders": {
        "X-Custom-Header": "CustomValue"
      }
    }
  }
}
EOF
)
  # Use curl to call the API with the request body
  curl -X POST "${CREATE_QUEUES_URL}" \
    -H "Content-Type: application/json" \
    -d "$request_body"
}

# Check if --ds option is passed
if [[ "$1" == "--ds" ]]; then
  download_samples
fi

# Loop to call create_email_queue 10 times with random number of files (1 to 5)
for i in {1..10}; do
  # Generate a random number between 1 and 5
  random_files_count=$((RANDOM % 5 + 1))

  echo "Creating email queue #$i with $random_files_count random attachments"
  create_email_queue $random_files_count  # Pass the random number of files to attach
done




