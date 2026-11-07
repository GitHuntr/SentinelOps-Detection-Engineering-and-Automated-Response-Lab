"""SentinelOps Core Configuration Module."""

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application runtime settings loaded from environment or .env file."""

    ENVIRONMENT: str = "development"
    LOG_LEVEL: str = "INFO"
    SOC_SERVER_HOST: str = "192.168.56.10"
    BACKEND_PORT: int = 8000
    FRONTEND_PORT: int = 3000

    # Security
    JWT_SECRET_KEY: str = "change_me_to_a_random_32_character_secret_key_in_production"
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7
    SENTINELOPS_WEBHOOK_KEY: str = "change_me_to_a_secure_preshared_webhook_token"

    # Database
    POSTGRES_HOST: str = "127.0.0.1"
    POSTGRES_PORT: int = 5432
    POSTGRES_DB: str = "sentinelops_db"
    POSTGRES_USER: str = "sentinelops_app"
    POSTGRES_PASSWORD: str = "change_me_sentinelops_db_password"
    DATABASE_URL: str = (
        "postgresql+asyncpg://sentinelops_app:change_me_sentinelops_db_password@127.0.0.1:5432/sentinelops_db"
    )

    # Wazuh SIEM
    WAZUH_API_HOST: str = "https://127.0.0.1"
    WAZUH_API_PORT: int = 55000
    WAZUH_API_USER: str = "wazuh-wui"
    WAZUH_API_PASSWORD: str = "change_me_wazuh_api_password"
    WAZUH_API_VERIFY_SSL: bool = False
    WAZUH_ALERTS_LOG_PATH: str = "/var/ossec/logs/alerts/alerts.json"

    # Threat Intelligence
    VIRUSTOTAL_API_KEY: str | None = None
    ABUSEIPDB_API_KEY: str | None = None

    # SOAR Governance
    EMERGENCY_KILL_SWITCH_ENABLED: bool = True
    HITL_APPROVAL_TIMEOUT_MINUTES: int = 15

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )


settings = Settings()

