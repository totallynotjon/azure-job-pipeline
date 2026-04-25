import logging

import azure.functions as func

app = func.FunctionApp()


@app.route(route="ping", auth_level=func.AuthLevel.ANONYMOUS)
def ping(req: func.HttpRequest) -> func.HttpResponse:
    logging.info("ping called")
    return func.HttpResponse("pong", status_code=200)
