# Clone the repository
git clone https://github.com/mahdiMGF2/mirzabot.git
cd mirzabot

# Create environment file
cp docker/.env.example docker/.env
# Edit docker/.env with your values

# Start services
docker compose up -d

# Check logs
docker compose logs -f app
