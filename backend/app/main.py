"""SentinelOps FastAPI Application Factory."""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import settings


def create_application() -> FastAPI:
    """Instantiate and configure the FastAPI Modular Monolith application."""
    app = FastAPI(
        title="SentinelOps API",
        description="Detection Engineering & Automated Response Lab API",
        version="0.1.0",
        docs_url="/docs",
        redoc_url="/redoc",
    )

    # Allowed origins: Windows 11 host browser and local interfaces
    origins = [
        f"http://{settings.SOC_SERVER_HOST}:{settings.FRONTEND_PORT}",
        f"http://localhost:{settings.FRONTEND_PORT}",
        f"http://127.0.0.1:{settings.FRONTEND_PORT}",
    ]

    app.add_middleware(
        CORSMiddleware,
        allow_origins=origins,
        allow_credentials=True,
        allow_methods=["GET", "POST", "PATCH", "DELETE", "OPTIONS"],
        allow_headers=["*"],
    )

    @app.get("/api/v1/health", tags=["System"])
    async def health_check() -> dict[str, str]:
        """Base health check verifying application responsiveness."""
        return {
            "status": "healthy",
            "environment": settings.ENVIRONMENT,
            "version": "0.1.0",
        }

    return app


app = create_application()

