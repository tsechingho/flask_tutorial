FROM python:3.6.13-alpine3.13

WORKDIR /srv/flask

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 5000

CMD ["python", "app.py"]
