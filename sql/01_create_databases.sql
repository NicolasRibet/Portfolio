CREATE DATABASE IF NOT EXISTS talent_flow_source
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_0900_ai_ci;

CREATE DATABASE IF NOT EXISTS talent_flow_analytics
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_0900_ai_ci;

CREATE USER IF NOT EXISTS
    'talent_flow_admin'@'localhost'
    IDENTIFIED BY 'mysql';

GRANT ALL PRIVILEGES
    ON talent_flow_source.*
    TO 'talent_flow_admin'@'localhost';

GRANT ALL PRIVILEGES
    ON talent_flow_analytics.*
    TO 'talent_flow_admin'@'localhost';

CREATE USER IF NOT EXISTS
    'metabase_reader'@'localhost'
    IDENTIFIED BY 'REPLACE_WITH_A_DIFFERENT_PASSWORD';

GRANT SELECT
    ON talent_flow_analytics.*
    TO 'metabase_reader'@'localhost';

FLUSH PRIVILEGES;