DEFAULT_SSH_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHWcmgRRfJQrUPXVT+P80O3f3f9Y9sAVBvjJe8Y3y5ui gomez@CamiloGomez"

# Reading user input for SSH key
read -p "Enter your SSH key (leave blank for default): " SSH_KEY

# Check if SSH_KEY is empty and set to DEFAULT_SSH_KEY if so
if [ -z "$SSH_KEY" ]; then
    SSH_KEY=$DEFAULT_SSH_KEY
fi

# Rest of the script remains unchanged