"""RunRacing real-time telemetry consumer (stand-in for Managed Service for
Apache Flink, which needs an application JAR - see Constraints & Omissions).

Triggered by a Kinesis event-source mapping; in production this is where rule-based
and statistical cheat/anomaly detection runs. The demo version logs the batch so
the streaming path is observable end to end.
"""
import base64
import json


def lambda_handler(event, context):
    records = event.get("Records", [])
    decoded = []
    for rec in records:
        try:
            payload = base64.b64decode(rec["kinesis"]["data"]).decode("utf-8")
            decoded.append(payload)
        except Exception:  # noqa: BLE001
            decoded.append("<undecodable>")
    print(json.dumps({"received": len(records), "sample": decoded[:5]}))
    return {"processed": len(records)}
