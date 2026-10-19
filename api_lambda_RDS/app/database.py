import json
import os
import pymysql
from pymysql.cursors import DictCursor



class Database:
    def get_connection(self):

        return pymysql.connect(
            host=os.environ["DB_HOST"],
            port=int(os.environ.get("DB_PORT", "3306")),
            user=os.environ["DB_USERNAME"],
            password=os.environ["DB_PASSWORD"],
            database=os.environ["DB_NAME"],
            connect_timeout=5,
            cursorclass=DictCursor,
            autocommit=True,
        )


    def ensure_schema(self, connection):
        """Create the table if it does not exist."""

        with connection.cursor() as cursor:
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS users (
                    user_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
                    user_name VARCHAR(100) NOT NULL,
                    user_age INT NOT NULL
                )
            """)


    def run_query(self, operation, *args):
        """Run one database operation and always close the connection."""
        connection = self.get_connection()

        try:
            self.ensure_schema(connection)

            with connection.cursor() as cursor:
                return operation(cursor, *args)
        finally:
            connection.close()


    def list_users(self):
        return self.run_query(
            lambda cursor: (
                cursor.execute(
                    "SELECT user_id, user_name, user_age FROM users ORDER BY user_id"
                ),
                cursor.fetchall()
            )[1]
        )


    def get_user(self, user_id):
        def query(cursor, uid):
            cursor.execute(
                "SELECT user_id, user_name, user_age "
                "FROM users WHERE user_id = %s",
                (uid,),
            )
            return cursor.fetchone()

        return self.run_query(query, user_id)


    def create_user(self,user_name, user_age):
        def query(cursor, name, age):
            cursor.execute(
                "INSERT INTO users (user_name, user_age) VALUES (%s, %s)",
                (name, age),
            )
            return {"user_id": cursor.lastrowid, "user_name": name, "user_age": age}

        return self.run_query(query, user_name, user_age)


    def update_user(self, user_id, user_name, user_age):
        def query(cursor, uid, name, age):
            cursor.execute(
                "UPDATE users SET user_name = %s, user_age = %s "
                "WHERE user_id = %s",
                (name, age, uid),
            )

            if cursor.rowcount == 0:
                cursor.execute(
                    "SELECT user_id FROM users WHERE user_id = %s", (uid,)
                )
                if cursor.fetchone() is None:
                    return None

            return {"user_id": uid, "user_name": name, "user_age": age}

        return self.run_query(query, user_id, user_name, user_age)


    def delete_user(self,user_id):
        def query(cursor, uid):
            cursor.execute("DELETE FROM users WHERE user_id = %s", (uid,))
            return cursor.rowcount > 0

        return self.run_query(query, user_id)

    def custom_query(self, sql):
        connection = self.get_connection()

        try:
            with connection.cursor() as cursor:
                cursor.execute(sql)

                if cursor.description:
                    return {
                        "columns": [col[0] for col in cursor.description],
                        "rows": cursor.fetchall(),
                    }

                return {
                    "message": "Query executed successfully",
                    "affected_rows": cursor.rowcount,
                }
        finally:
            connection.close()