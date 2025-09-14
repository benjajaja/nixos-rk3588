from zigpy.quirks.v2 import (
    QuirkBuilder,
    ReportingConfig,
    SensorDeviceClass,
    SensorStateClass
)
from zigpy.zcl.clusters.general import AnalogInput
(
    QuirkBuilder("esphome", "particles-esphome")
    .sensor(
        attribute_name="present_value",
        cluster_id=AnalogInput.cluster_id, # 0x000c works too
        endpoint_id=4,
        state_class=SensorStateClass.MEASUREMENT,
        device_class=SensorDeviceClass.PM1,
        unit="µg/m³",
        reporting_config=ReportingConfig(
            min_interval=10, max_interval=120, reportable_change=1
        ),
        translation_key="pm1",
        fallback_name="PM1",
    )
    .sensor(
        attribute_name="present_value",
        cluster_id=AnalogInput.cluster_id, # 0x000c works too
        endpoint_id=5,
        state_class=SensorStateClass.MEASUREMENT,
        device_class=SensorDeviceClass.PM10,
        unit="µg/m³",
        reporting_config=ReportingConfig(
            min_interval=10, max_interval=120, reportable_change=1
        ),
        translation_key="pm10",
        fallback_name="PM10",
    )
    .sensor(
        attribute_name="present_value",
        cluster_id=AnalogInput.cluster_id, # 0x000c works too
        endpoint_id=6,
        state_class=SensorStateClass.MEASUREMENT,
        device_class=SensorDeviceClass.AQI,
        reporting_config=ReportingConfig(
            min_interval=10, max_interval=120, reportable_change=1
        ),
        translation_key="voc_index",
        fallback_name="VOC index",
    )
    .add_to_registry()
)
