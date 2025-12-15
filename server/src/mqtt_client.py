import paho.mqtt.client as mqtt
from config import MQTT_CONFIG
import threading
import logging

log = logging.getLogger(__name__)

class MQTTClient:
    def __init__(self):
        self.client = mqtt.Client()
        self.client.on_message = self.on_message
        self.client.on_connect = self.on_connect
        self.current_value = 0.0
        self.value_received = threading.Event()
        self.lock = threading.Lock()

    def on_message(self, client, userdata, msg):
        try:
            with self.lock:
                self.current_value = float(msg.payload.decode('utf-8').strip())
            log.info(f"Полученно значение {self.current_value}")
            self.value_received.set()
        except ValueError as e:
            log.error(f"Ошибка конвертации полученной строки в float: {e}")

    def on_connect(self, client, userdata, flags, rc):
        if rc == 0:
            log.info("Успешное подключение к MQTT брокеру")
            self.client.subscribe("weight/out")
            log.info("Подписан на топик weight")
        else:
            log.error(f"Ошибка подключения. Код: {rc}")
    
    def connect(self):
        try:
            self.client.connect(
                MQTT_CONFIG['broker'],
                MQTT_CONFIG['port'],
                MQTT_CONFIG['keepalive']
            )
        except Exception as e:
            log.error(f"Ошибка подключения: {e}")

    def publish(self, payload, qos=2, retain=False):
        self.value_received.clear()
        self.client.publish("weight/in", payload, qos, retain)

    def wait_for_value(self, timeout=10.0):
        received = self.value_received.wait(timeout)
        if received:
            with self.lock:
                val = self.current_value
            self.current_value = 0.0
            return val

        else:
            log.warning(f"Таймаут ожидания значения ({timeout} сек)")
            return None


    def start(self):
        self.connect()
        self.client.loop_start()

    def stop(self):
        self.client.loop_stop()
        self.client.disconnect()



    

