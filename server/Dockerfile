FROM ubuntu:22.04

ENV TZ=Europe/Moscow
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

RUN apt-get update && apt-get install -y \
    qtbase5-dev \
    qtchooser \
    qt5-qmake \
    qtbase5-dev-tools \
    build-essential \
    libqt5sql5 \
    libqt5sql5-psql \
    libpq-dev \
    postgresql-client \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /root/server/

COPY *.cpp /root/server/
COPY *.h /root/server/
COPY *.pro /root/server/
COPY send_email.py /root/server/

RUN qmake server.pro && make

EXPOSE 33333

ENTRYPOINT ["./server"]
