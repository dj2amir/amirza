-- MirzaBot Docker Initialization
-- This script runs automatically when the MySQL container starts for the first time

-- Ensure proper character set
ALTER DATABASE mirzabot CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- The actual table creation is handled by table.php
-- This file is for any additional MySQL configuration needed

-- Create a user with proper privileges (backup, in case env vars don't work)
-- GRANT ALL PRIVILEGES ON mirzabot.* TO 'mirzabot'@'%';
-- FLUSH PRIVILEGES;
