#!/bin/bash
# 1.	Takes an existing raw disk image (INPUT_RAW) as input.
# 2.	Creates a new larger raw image to hold LUKS2 encryption header + original data.
# 3.	Encrypts the entire new image using LUKS2.
# 4.	Opens it via cryptsetup and copies the full raw image data into the LUKS container using dd.
# 5.	Closes the LUKS mapping and enrolls the encrypted image with TPM2 for auto-unlock.

set -e  # Stop on errors

# Function to check and install a dependency if missing
check_and_install() {
    local cmd="$1"
    local pkg="$2"
    if ! command -v "$cmd" &> /dev/null; then
        echo "❌ Error: $cmd is required but not installed. Attempting to install $pkg..."
        if ! sudo apt update && sudo apt install -y "$pkg"; then
            echo "❌ Failed to install $pkg. Please install it manually with 'sudo apt install $pkg' and rerun the script."
            exit 1
        fi
        echo "✅ Successfully installed $pkg."
    fi
}

# Check dependencies
check_and_install "jq" "jq"
check_and_install "qemu-img" "qemu-utils"
check_and_install "cryptsetup" "cryptsetup"
check_and_install "expect" "expect"

# Check if LUKS password is set
if [ -z "$LUKS_PASSWORD" ]; then
    echo "❌ Error: LUKS_PASSWORD environment variable is not set."
    echo "Example: export LUKS_PASSWORD='your_secure_passphrase'"
    exit 1
fi

# Configuration
INPUT_RAW="$1"  # Source unencrypted raw image
ENCRYPTED_RAW="$2"  # Output encrypted raw image
MAPPER_NAME="encrypted_vm"
LUKS_HEADER_SIZE=16777216  # 16MB for LUKS2 header

if [ -z "$INPUT_RAW" ] || [ -z "$ENCRYPTED_RAW" ]; then
    echo "Usage: $0 <input_raw_image> <output_encrypted_raw>"
    echo "Example: $0 ./input.raw ./output-encrypted.raw"
    exit 1
fi

# Ensure input file exists
if [ ! -f "$INPUT_RAW" ]; then
    echo "❌ Error: Input file '$INPUT_RAW' does not exist."
    exit 1
fi

# Ensure output directory exists
OUTPUT_DIR=$(dirname "$ENCRYPTED_RAW")
if [ ! -d "$OUTPUT_DIR" ]; then
    echo "📁 Creating output directory '$OUTPUT_DIR'..."
    mkdir -p "$OUTPUT_DIR" || { echo "❌ Failed to create directory '$OUTPUT_DIR'."; exit 1; }
fi

echo "🔍 Calculating required disk size..."
VIRTUAL_SIZE=$(qemu-img info --output=json "$INPUT_RAW" | jq '."virtual-size"')
TOTAL_SIZE=$((VIRTUAL_SIZE + LUKS_HEADER_SIZE))
echo "📏 Input: $(numfmt --to=iec $VIRTUAL_SIZE), LUKS Header: 16MB, Total: $(numfmt --to=iec $TOTAL_SIZE)"

echo "🧹 Cleaning up any previous mappings..."
if sudo cryptsetup status "$MAPPER_NAME" >/dev/null 2>&1; then
    sudo cryptsetup luksClose "$MAPPER_NAME" || echo "⚠️ Warning: Failed to close existing mapping, proceeding anyway."
fi

sudo losetup -j "$ENCRYPTED_RAW" | cut -d: -f1 | while read -r loop; do
    sudo losetup -d "$loop" || echo "⚠️ Warning: Failed to detach loop device $loop, proceeding anyway."
done

echo "📌 Creating dynamically sized encrypted image..."
qemu-img create -f raw "$ENCRYPTED_RAW" "$TOTAL_SIZE" || { echo "❌ Failed to create encrypted image."; exit 1; }

LOOP_DEV=$(sudo losetup --show --find "$ENCRYPTED_RAW")
if [ -z "$LOOP_DEV" ]; then
    echo "❌ Error: Failed to set up loop device for '$ENCRYPTED_RAW'."
    exit 1
fi
echo "📌 Using loop device: $LOOP_DEV"

echo "🔒 Formatting with LUKS2..."
echo "$LUKS_PASSWORD" | sudo cryptsetup luksFormat --type luks2 "$LOOP_DEV" --batch-mode || { echo "❌ Failed to format with LUKS2."; exit 1; }

echo "🔓 Opening encrypted device..."
echo "$LUKS_PASSWORD" | sudo cryptsetup luksOpen "$LOOP_DEV" "$MAPPER_NAME" || { echo "❌ Failed to open encrypted device."; exit 1; }

echo "🔄 Copying data with correct sector alignment..."
sudo dd if="$INPUT_RAW" of=/dev/mapper/"$MAPPER_NAME" bs=4M status=progress || { echo "❌ Failed to copy data."; exit 1; }

echo "📦 Closing device for TPM enrollment..."
sudo cryptsetup luksClose "$MAPPER_NAME" || { echo "❌ Failed to close encrypted device."; exit 1; }

echo "🔑 Adding TPM2 auto-unlock..."
/usr/bin/expect <<EOF || { echo "❌ Failed to enroll TPM2 key."; exit 1; }
spawn sudo systemd-cryptenroll --wipe-slot=1 --tpm2-device=auto --tpm2-pcrs=1+3+5+7+11+12+14+15 "$LOOP_DEV"
expect "Please enter current passphrase for disk $LOOP_DEV:"
send "$LUKS_PASSWORD\r"
expect "New TPM2 token enrolled as key slot 1." {exit 0} timeout {exit 1}
EOF

echo "🔍 Final verification:"
sudo cryptsetup luksDump "$LOOP_DEV" || echo "⚠️ Warning: Failed to dump LUKS info, but setup may still be complete."
sudo losetup -d "$LOOP_DEV" || echo "⚠️ Warning: Failed to detach loop device $LOOP_DEV."

echo "✅ Encryption and TPM2 setup complete!"
echo "ℹ️ Check the 'Keyslots' section above for slot 1 to confirm TPM2 enrollment."
