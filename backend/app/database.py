import os
from pathlib import Path
from urllib.parse import quote_plus

from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker


def _read_required_secret(path_value: str | None, name: str) -> str:
    if not path_value:
        raise RuntimeError(f"{name} secret file is not configured")

    path = Path(path_value)

    if not path.is_file():
        raise RuntimeError(f"{name} secret file does not exist: {path}")

    value = path.read_text(encoding="utf-8").strip()

    if not value:
        raise RuntimeError(f"{name} secret is empty")

    return value


def _build_database_url() -> str:
    explicit_url = os.getenv("DATABASE_URL")

    if explicit_url:
        return explicit_url

    password = _read_required_secret(
        os.getenv("DB_PASSWORD_FILE"),
        "Database password",
    )

    user = os.getenv("DB_USER", "devops")
    host = os.getenv("DB_HOST", "db")
    port = os.getenv("DB_PORT", "5432")
    name = os.getenv("DB_NAME", "devops")

    return f"postgresql://{quote_plus(user)}:{quote_plus(password)}@{host}:{port}/{name}"


DATABASE_URL = _build_database_url()

engine = create_engine(DATABASE_URL)

SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine,
)

Base = declarative_base()


def get_db():
    db = SessionLocal()

    try:
        yield db
    finally:
        db.close()
