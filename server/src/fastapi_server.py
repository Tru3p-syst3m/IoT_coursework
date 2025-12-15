import uvicorn
import asyncio
import logging
from api.endpoints import app

log = logging.getLogger(__name__)

def run_fastapi():
    """Запуск FastAPI сервера"""
    config = uvicorn.Config(
        app=app,
        host="0.0.0.0",
        port=8000,
        log_level="info"
    )
    server = uvicorn.Server(config)
    
    log.info("FastAPI сервер запускается...")
    asyncio.run(server.serve())

if __name__ == "__main__":
    run_fastapi()