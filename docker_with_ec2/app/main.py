from fastapi import FastAPI

app = FastAPI()

@app.get("/")
def health():
    return {"status" : 200, "data" : "Fast - api service is running"}


@app.get("/api/getItems/{item_id}")
def getItem(item_id:int):
    items = {
        1 : "Notepad",
        2 : "Laptop",
        3 : "Mouse",
        4 : "key-Board"
    }

    data = {
        "item_id" : item_id,
        "item_name" : items[item_id]
    }

    return {"status" : 200, "data" : data}

@app.get("/api/getUser/{user_id}")
def getUser(user_id:int):
    users = {
        1 : "Aravind",
        2 : "Varun",
        3 : "Varsha",
        4 : "Chaitra"
    }

    data = {
        "user_id" : user_id,
        "user_name" : users[user_id]
    }

    return {"status" : 200, "data" : data}
