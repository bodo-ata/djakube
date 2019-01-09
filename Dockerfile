FROM python:3.7.0
ENV PYTHONUNBUFFERED 1
RUN mkdir /code
ADD ./requirements.txt /tmp/requirements.txt
WORKDIR /code
RUN pip install -r /tmp/requirements.txt
ADD . /code/
ENTRYPOINT ["/code/manage.py"]
CMD ["runserver", "0.0.0.0:8000"]