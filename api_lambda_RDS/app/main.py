import json
from database import Database

db = Database()

def response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body, default=str),
    }


def lambda_handler(event, context):
    method = event.get("httpMethod", "")
    resource = event.get("resource", "")
    path_params = event.get("pathParameters") or {}
    user_id = path_params.get("user_id")

    try:
        if resource == "/users":
            if method == "GET":
                return response(200, db.list_users())

            if method == "POST":
                body = json.loads(event.get("body") or "{}")
                name = body.get("user_name")
                age = body.get("user_age")

                if not isinstance(name, str) or not name.strip():
                    return response(400, {"error": "user_name is required"})

                if isinstance(age, bool) or not isinstance(age, int) or age < 0:
                    return response(400, {"error": "user_age must be a non-negative integer"})

                user = db.create_user(name.strip(), age)
                return response(201, user)

        elif resource == "/users/{user_id}":
            if not user_id.isdigit() or int(user_id) < 1:
                return response(400, {"error": "Invalid user_id"})

            uid = int(user_id)

            if method == "GET":
                user = db.get_user(uid)
                return (
                    response(200, user)
                    if user
                    else response(404, {"error": "User not found"})
                )

            if method == "PUT":
                body = json.loads(event.get("body") or "{}")
                name = body.get("user_name")
                age = body.get("user_age")

                if not isinstance(name, str) or not name.strip():
                    return response(400, {"error": "user_name is required"})

                if isinstance(age, bool) or not isinstance(age, int) or age < 0:
                    return response(400, {"error": "user_age must be a non-negative integer"})

                user = db.update_user(uid, name.strip(), age)
                return (
                    response(200, user)
                    if user
                    else response(404, {"error": "User not found"})
                )

            if method == "DELETE":
                deleted = db.delete_user(uid)
                return (
                    response(200, {"message": "User deleted"})
                    if deleted
                    else response(404, {"error": "User not found"})
                )
            
        elif resource == "/query" and method == "POST":
            try:
                body = json.loads(event.get("body") or "{}")
            except json.JSONDecodeError:
                return response(400, {"error": "Invalid JSON body"})

            sql = body.get("query")

            if not isinstance(sql, str) or not sql.strip():
                return response(400, {"error": "query is required"})

            try:
                result = db.custom_query(sql)
                return response(200, result)
            except Exception:
                print("Custom SQL execution failed; inspect CloudWatch logs.")
                return response(500, {"error": "SQL execution failed"})


        return response(404, {"error": "Route not found"})
    

    except json.JSONDecodeError:
        return response(400, {"error": "Request body must be valid JSON"})
    except Exception:
        # Keep database credentials and internal error details out of API responses.
        print("Request failed; inspect the Lambda CloudWatch logs.")
        return response(500, {"error": "Internal server error"})