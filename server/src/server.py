import threading
import logging
import time
from api.dependencies import init_components, cleanup_components
from fastapi_server import run_fastapi

logging.basicConfig(
    level=logging.INFO,
    format='[%(name)s] %(levelname)s: %(message)s',
    force=True
)

log = logging.getLogger(__name__)

def main():
    try:
        init_components()
        log.info("Компоненты инициализированы")
        
        api_thread = threading.Thread(target=run_fastapi, daemon=True)
        api_thread.start()
        
        # Ждем запуска сервера
        time.sleep(3)
        try:
            while True:
                # Здесь можно добавить мониторинг состояния системы
                # Например, проверку соединения MQTT
                time.sleep(5)
                
        except KeyboardInterrupt:
            log.info("Получен сигнал прерывания")
            
    except Exception as e:
        log.error(f"Ошибка запуска системы: {e}")
    finally:
        # Очистка ресурсов
        cleanup_components()
        log.info("Программа завершена")

if __name__ == "__main__":
    main()