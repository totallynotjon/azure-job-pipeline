FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY scrape.py .

RUN useradd --create-home --shell /bin/bash scraper
USER scraper

CMD ["python", "scrape.py"]
