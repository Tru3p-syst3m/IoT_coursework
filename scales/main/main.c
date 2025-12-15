#include "driver/gpio.h"
#include "esp_event.h"
#include "esp_log.h"
#include "esp_system.h"
#include "esp_vfs_dev.h"
#include "esp_wifi.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "mqtt_client.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// WiFi setting
#define WIFI_SSID "BLESSING"
#define WIFI_PASS "nice cock!"
static const char *WIFI_TAG = "WIFI";

// HX711 setting
#define SCALE 384.279083
#define HX711_DT_GPIO GPIO_NUM_21
#define HX711_SCK_GPIO GPIO_NUM_22

typedef struct {
  int dt_pin;
  int sck_pin;
  int gain;
  int offset;
  float scale;
} hx711_t;

static const char *HX711_TAG = "HX711";

// mqtt setting
#define MQTT_BROKER_URI "mqtt://192.168.3.2:1883"
static const char *MQTT_TAG = "MQTT";

int mqtt_connection;
int input_flag = 0;

void hx711_init(hx711_t *hx, int dt_pin, int sck_pin) {
  hx->dt_pin = dt_pin;
  hx->sck_pin = sck_pin;
  hx->gain = 128;
  hx->offset = 0;
  hx->scale = 1.0;

  // Настройка пинов
  gpio_set_direction(dt_pin, GPIO_MODE_INPUT);
  gpio_set_direction(sck_pin, GPIO_MODE_OUTPUT);

  // Начальное состояние
  gpio_set_level(sck_pin, 0);
}

int32_t hx711_read(hx711_t *hx) {
  // Ждем пока данные готовы (DT становится LOW)
  while (gpio_get_level(hx->dt_pin) == 1) {
    vTaskDelay(1 / portTICK_PERIOD_MS);
  }

  int32_t data = 0;

  // Читаем 24 бита данных
  for (int i = 0; i < 24; i++) {
    gpio_set_level(hx->sck_pin, 1);
    esp_rom_delay_us(1);

    data <<= 1;
    if (gpio_get_level(hx->dt_pin)) {
      data++;
    }

    gpio_set_level(hx->sck_pin, 0);
    esp_rom_delay_us(1);
  }

  // Устанавливаем усиление для следующего чтения
  for (int i = 0; i < hx->gain; i++) {
    gpio_set_level(hx->sck_pin, 1);
    esp_rom_delay_us(1);
    gpio_set_level(hx->sck_pin, 0);
    esp_rom_delay_us(1);
  }

  // Преобразование в знаковое 32-битное число
  if (data & 0x800000) {
    data |= 0xFF000000;
  }

  return data;
}

int32_t hx711_read_average(hx711_t *hx, int times) {
  int64_t sum = 0;
  for (int i = 0; i < times; i++) {
    sum += hx711_read(hx);
    vTaskDelay(10 / portTICK_PERIOD_MS);
  }
  return sum / times;
}

void hx711_tare(hx711_t *hx, int times) {
  int32_t avg = hx711_read_average(hx, times);
  hx->offset = avg;
  ESP_LOGI(HX711_TAG, "Tare complete. Offset: %ld", hx->offset);
}

void hx711_set_scale(hx711_t *hx, float scale) { hx->scale = scale; }

float hx711_get_units(hx711_t *hx, int times) {
  int32_t value = hx711_read_average(hx, times) - hx->offset;
  return (float)value / hx->scale;
}

static void mqtt_event_handler(void *handler_args, esp_event_base_t base,
                               int32_t event_id, void *event_data) {
  esp_mqtt_event_handle_t event = event_data;

  switch ((esp_mqtt_event_id_t)event_id) {
  case MQTT_EVENT_CONNECTED:
    int msg_id = esp_mqtt_client_subscribe(event->client, "weight/in", 1);
    mqtt_connection = 1;
    ESP_LOGI(MQTT_TAG, "MQTT подключен! msg_id = %d", msg_id);
    break;

  case MQTT_EVENT_DISCONNECTED:
    ESP_LOGI(MQTT_TAG, "MQTT отключен");
    mqtt_connection = 0;
    break;

  case MQTT_EVENT_DATA:
    ESP_LOGI(MQTT_TAG, "Получен сигнал");
    char message[64];
    int len = event->data_len < sizeof(message) - 1 ? event->data_len
                                                    : sizeof(message) - 1;
    memcpy(message, event->data, len);
    message[len] = '\0';
    if (strcmp(message, "get") == 0) {
      input_flag = 1;
    }
    break;

  case MQTT_EVENT_ERROR:
    ESP_LOGI(MQTT_TAG, "MQTT ошибка");
    break;
  default:
    break;
  }
}

void wifi_connect_simple() {
  ESP_ERROR_CHECK(esp_netif_init());
  ESP_ERROR_CHECK(esp_event_loop_create_default());
  esp_netif_create_default_wifi_sta();

  wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
  cfg.nvs_enable = false;
  ESP_ERROR_CHECK(esp_wifi_init(&cfg));

  wifi_config_t wifi_config = {
      .sta =
          {
              .ssid = WIFI_SSID,
              .password = WIFI_PASS,
              .scan_method = WIFI_ALL_CHANNEL_SCAN,
              .sort_method = WIFI_CONNECT_AP_BY_SIGNAL,
          },
  };

  ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA));
  ESP_ERROR_CHECK(esp_wifi_set_config(WIFI_IF_STA, &wifi_config));
  ESP_ERROR_CHECK(esp_wifi_start());
  ESP_ERROR_CHECK(esp_wifi_connect());
}

void app_main() {
  // HX711 init
  hx711_t scales;
  hx711_init(&scales, HX711_DT_GPIO, HX711_SCK_GPIO);
  hx711_tare(&scales, 10);
  hx711_set_scale(&scales, SCALE);

  // wifi init
  wifi_connect_simple();

  vTaskDelay(pdMS_TO_TICKS(10000));

  // mqtt init
  esp_mqtt_client_config_t mqtt_cfg = {
      .broker.address.uri = MQTT_BROKER_URI,
  };
  esp_mqtt_client_handle_t client = esp_mqtt_client_init(&mqtt_cfg);
  esp_mqtt_client_register_event(client, ESP_EVENT_ANY_ID, mqtt_event_handler,
                                 NULL);
  esp_mqtt_client_start(client);

  // main cycle
  char message[64];
  while (1) {
    if (input_flag == 1) {
      float weight = hx711_get_units(&scales, 10);
      sprintf(message, "%.2f", weight);
      ESP_LOGI(HX711_TAG, "Weight: %s g", message);
      esp_mqtt_client_publish(client, "weight/out", message, strlen(message), 2,
                              0);
      input_flag = 0;
    }
    vTaskDelay(pdMS_TO_TICKS(500));
  }
}