
from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional
import logging
from api.dependencies import get_mqtt_client, get_bd_handler

log = logging.getLogger(__name__)

app = FastAPI(
    title="Products API with MQTT",
    description="API для управления продуктами с интеграцией MQTT весов",
    version="1.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class WeightResponse(BaseModel):
    weight: float
    unit: str = "g"
    timestamp: float

# ================== API ЭНДПОИНТЫ ==================

@app.get("/")
async def root():
    """Корневой эндпоинт с информацией"""
    mqtt_client = get_mqtt_client()
    
    return {
        "message": "Products API with MQTT",
        "endpoints": {
            "get_weight": "GET /api/get_weight",
        },
        "status": {
            "mqtt": "connected" if mqtt_client and mqtt_client.is_connected() else "disconnected"
        }
    }

@app.get("/api/get_weight", response_model=WeightResponse)
async def get_weight():
    """Получить все продукты из базы данных"""
    try:
        mqtt_client = get_mqtt_client
        if not mqtt_client:
            raise HTTPException(status_code=503, detail="mqtt client offline")
        mqtt_client.publish("get")
        weight = mqtt_client.wait_for_value()
        return weight
    except Exception as e:
        log.error(f"Ошибка при получении продуктов: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# @app.post("/api/products")
# async def add_product(request: AddProductRequest):
#     """Добавить продукт с весом (с весов или указанным)"""
#     try:
#         mqtt_client = get_mqtt_client()
        
#         # Определяем вес
#         if request.weight is None:
#             # Получаем вес с весов
#             if not mqtt_client or not mqtt_client.is_connected():
#                 raise HTTPException(status_code=503, detail="MQTT клиент не подключен")
            
#             mqtt_client.publish("get")
#             weight_value = mqtt_client.wait_for_value(timeout=10)
            
#             if weight_value is None:
#                 raise HTTPException(status_code=408, detail="Не удалось получить вес с весов")
            
#             weight = weight_value
#             source = "весы"
#         else:
#             # Используем указанный вес
#             weight = request.weight
#             source = "вручную"
        
#         # Добавляем в БД
#         success = process_db_command(request.name, weight)
        
#         if not success:
#             raise HTTPException(status_code=500, detail="Ошибка при добавлении в БД")
        
#         return {
#             "success": True,
#             "message": f"Продукт '{request.name}' добавлен",
#             "details": {
#                 "weight": weight,
#                 "source": source,
#                 "product": request.name
#             }
#         }
        
#     except HTTPException:
#         raise
#     except Exception as e:
#         log.error(f"Ошибка при добавлении продукта: {e}")
#         raise HTTPException(status_code=500, detail=str(e))

# @app.get("/api/weight")
# async def get_current_weight():
#     """Получить текущий вес с весов"""
#     try:
#         mqtt_client = get_mqtt_client()
        
#         if not mqtt_client or not mqtt_client.is_connected():
#             raise HTTPException(status_code=503, detail="MQTT клиент не подключен")
        
#         mqtt_client.publish("get")
#         weight = mqtt_client.wait_for_value(timeout=5)
        
#         if weight is None:
#             raise HTTPException(status_code=408, detail="Не удалось получить вес")
        
#         return WeightResponse(
#             weight=weight,
#             timestamp=time.time()
#         )
        
#     except HTTPException:
#         raise
#     except Exception as e:
#         raise HTTPException(status_code=500, detail=str(e))

# @app.get("/api/status", response_model=StatusResponse)
# async def get_system_status():
#     """Получить статус всей системы"""
#     try:
#         mqtt_client = get_mqtt_client()
#         command_queue = get_command_queue()
#         bd_handler = get_bd_handler()
        
#         # Проверяем подключение к БД
#         db_connected = False
#         if bd_handler:
#             try:
#                 products = bd_handler.get_all_entity()
#                 db_connected = True
#             except:
#                 db_connected = False
        
#         return StatusResponse(
#             mqtt_status="connected" if mqtt_client and mqtt_client.is_connected() else "disconnected",
#             queue_size=command_queue.qsize() if command_queue else 0,
#             db_connected=db_connected
#         )
        
#     except Exception as e:
#         raise HTTPException(status_code=500, detail=str(e))

# @app.post("/api/command")
# async def send_command(request: CommandRequest):
#     """Отправить команду в систему"""
#     try:
#         mqtt_client = get_mqtt_client()
        
#         if request.command == "tare":
#             if not mqtt_client:
#                 raise HTTPException(status_code=503, detail="MQTT клиент не доступен")
            
#             mqtt_client.publish("tare")
#             return {"success": True, "message": "Команда тарирования отправлена"}
            
#         elif request.command == "add_product":
#             if not request.product_name:
#                 raise HTTPException(status_code=400, detail="Не указано название продукта")
            
#             # Определяем вес
#             if request.weight:
#                 weight = request.weight
#                 source = "указан"
#             else:
#                 if not mqtt_client:
#                     raise HTTPException(status_code=503, detail="MQTT клиент не доступен")
                
#                 mqtt_client.publish("get")
#                 weight = mqtt_client.wait_for_value(timeout=5)
#                 if weight is None:
#                     raise HTTPException(status_code=408, detail="Не удалось получить вес")
#                 source = "с весов"
            
#             # Добавляем в БД
#             success = process_db_command(request.product_name, weight)
            
#             if not success:
#                 raise HTTPException(status_code=500, detail="Ошибка при добавлении в БД")
            
#             return {
#                 "success": True,
#                 "message": f"Продукт '{request.product_name}' добавлен",
#                 "weight": weight,
#                 "source": source
#             }
            
#         else:
#             raise HTTPException(status_code=400, detail="Неизвестная команда")
            
#     except HTTPException:
#         raise
#     except Exception as e:
#         raise HTTPException(status_code=500, detail=str(e))

# @app.get("/health")
# async def health_check():
#     """Проверка здоровья системы"""
#     try:
#         mqtt_client = get_mqtt_client()
        
#         components = {
#             "api": "ok",
#             "mqtt": "connected" if mqtt_client and mqtt_client.is_connected() else "disconnected",
#             "database": "unknown"
#         }
        
#         # Проверяем БД
#         try:
#             bd_handler = get_bd_handler()
#             if bd_handler:
#                 products = bd_handler.get_all_entity()
#                 components["database"] = f"ok ({len(products)} products)"
#         except:
#             components["database"] = "error"
        
#         return {
#             "status": "healthy" if all(v != "error" for v in components.values()) else "degraded",
#             "components": components,
#             "timestamp": time.time()
#         }
        
#     except Exception as e:
#         return {
#             "status": "unhealthy",
#             "error": str(e),
#             "timestamp": time.time()
#         }