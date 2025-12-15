import logging
from mqtt_client import MQTTClient

log = logging.getLogger(__name__)

mqtt_client = None

def init_components():
    global mqtt_client

    try:
        mqtt_client = MQTTClient()
        mqtt_client.start()
        log.info("MQTT клиент инициализирован")
    except Exception as e:
        log.error(f"Ошибка инициализации MQTT: {e}")
        mqtt_client = None

def cleanup_components():
    global mqtt_client
    
    log.info("Остановка компонентов...")
    
    if mqtt_client:
        mqtt_client.stop()
        log.info("MQTT клиент остановлен")

def get_mqtt_client():
    return mqtt_client
