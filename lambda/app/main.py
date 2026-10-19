
import json
import math


def lambda_handler(event, context):
    try:
        body = event.get("body")

        if isinstance(body, str):
            body = json.loads(body)

        if not isinstance(body, dict):
            raise ValueError("Request body must be a JSON object")

        a = body.get("a")
        b = body.get("b")
        operation = body.get("operation")

        if (
            isinstance(a, bool)
            or isinstance(b, bool)
            or not isinstance(a, (int, float))
            or not isinstance(b, (int, float))
            or not math.isfinite(a)
            or not math.isfinite(b)
        ):
            raise ValueError("a and b must be finite numbers")

        if operation == "add":
            result = a + b
        elif operation == "subtract":
            result = a - b
        elif operation == "multiply":
            result = a * b
        elif operation == "divide":
            if b == 0:
                return response(400, {"error": "Cannot divide by zero"})
            result = a / b
        else:
            raise ValueError(
                "operation must be add, subtract, multiply, or divide"
            )

        if not math.isfinite(result):
            return response(400, {"error": "Result is not finite"})

        return response(200, {
            "a": a,
            "b": b,
            "operation": operation,
            "result": result
        })

    except (ValueError, TypeError, json.JSONDecodeError) as exc:
        return response(400, {"error": str(exc)})


def response(status_code, data):
    return {
        "statusCode": status_code,
        "headers": {"content-type": "application/json"},
        "body": json.dumps(data)
    }
