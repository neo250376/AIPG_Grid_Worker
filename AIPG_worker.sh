#!/bin/bash

sudo apt-get update

echo -e "\e[32mInstalling Nvidia Drivers....\e[0m"

# Check if NVIDIA driver is already installed
if ! dpkg -l | grep -q nvidia-driver; then
    echo -e "\e[32mNvidia driver is not installed. Proceeding with installation...\e[0m"
    sleep 5
    sudo apt-get install -y nvidia-driver-550 
    sudo nvidia-smi > /dev/null
    echo -e "\e[32mNvidia drivers installed successfully\e[0m"
else
    echo -e "\e[32mNvidia driver is already installed.\e[0m"
fi

sleep 3

# Add Docker's official GPG key:
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo service docker start

curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
  && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

sudo apt-get update

sudo apt-get install -y nvidia-container-toolkit

git clone https://github.com/gonner22/AIPG-GenHub

cd AIPG-GenHub

sudo apt install -y python3.10-venv

python3 -m venv venv

source venv/bin/activate

pip install pyyaml

# Prompt user for input
echo -e "\e[32mEnter your Worker Name:\e[0m"
read worker_name

echo -e "\e[32mEnter your Scribe Name (must be different to your Worker Name):\e[0m"
read scribe_name

echo -e "\e[32mEnter your Grid API Key:\e[0m"
read api_key

echo -e "\e[32mEnter Hugging Face Token:\e[0m"
read hf_token

# Create bridgeData.yaml file
cat << EOF > bridgeData.yaml
## Common for all worker Types

# The grid url
horde_url: "https://api.aipowergrid.io/"
# Give a cool name to your instance
worker_name: "$worker_name"
# The api_key identifies a unique user in the grid
# Visit [Add aipg register url] to create one before you can join
api_key: "$api_key"
# Put other users whose prompts you want to prioritize.
# The owner's username is always included so you don't need to add it here,
max_threads: 1
# We will keep this many requests in the queue so we can start working as soon as a thread is available
# Recommended to keep no higher than 1
queue_size: 0


## Text Gen

# The name to use when running a scribe worker. Will default to \`worker_name\` if not set
scribe_name: "$scribe_name"
# The KoboldAI Client API URL 
# By default, this should be http://<container_name>:7860, in our template is set to: http://aphrodite-engine:7860. 
# Attention: the 'container_name' field refers to the name of the Aphrodite container.
kai_url: "http://aphrodite-engine:7860"
# The max amount of tokens to generate with this worker 
max_length: 512
# The max tokens to use from the prompt
max_context_length: 1024
EOF

# Create config.yaml file
cat << EOF > config.yaml
worker_config:
  exec_type: it
  ports: "443:443"
  network: ai_network
  container_name: worker
  image_name: worker-image

aphrodite_config:
  exec_type: it
  ports: "2242:7860"
  network: ai_network
  container_name: aphrodite-engine
  gpus: "all"
  shm-size: "8g"
  env:
    - MODEL_NAME=meta-llama/Meta-Llama-3-8B-Instruct #or use TheBloke/Mistral-7B-v0.1-GPTQ #See list of models supported, take note of required VRAM
    - KOBOLD_API=true
    - GPU_MEMORY_UTILIZATION=0.9 #If you are running out of memory, consider decreasing this value
    - HF_TOKEN=$hf_token  #Your hugging face token: https://huggingface.co/settings/tokens
    #- CONTEXT_LENGTH=4096 # If unspecified, will be automatically derived from the model.
  image_name: alpindale/aphrodite-engine
EOF

echo -e "\e[32mFiles bridgeData.yaml and config.yaml created successfully.\e[0m"

sleep 5

echo -e "\e[32mTo run the textgen worker please type \e[1;33msudo python3 worker_texgen.py\e[0m \e[32mwhen setup exits.\e[0m"

echo -e "\e[32mTo cleanup folders please type \e[1;33m./cleanup.sh\e[0m\e[32m.\e[0m"
